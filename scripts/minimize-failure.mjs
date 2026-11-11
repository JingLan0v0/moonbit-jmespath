import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { minimizeCases, responseSignature } from './lib/failure-reducer.mjs';
import { expectedFor } from './lib/case-oracle.mjs';

const root = path.resolve(import.meta.dirname, '..');
const args = process.argv.slice(2);
const options = {};
for (let i = 0; i < args.length; i++) {
  const key = args[i];
  if (Object.hasOwn(options, key)) throw new Error('Duplicate option: ' + key);
  if (key === '--release') options[key] = true;
  else if (['--suite', '--input', '--output-dir', '--max-attempts', '--max-ms', '--timeout-ms'].includes(key) && args[i + 1]) options[key] = args[++i];
  else throw new Error('Usage: node scripts/minimize-failure.mjs --suite equality|composition --input FILE [--release] [--output-dir DIR] [--max-attempts N] [--max-ms N] [--timeout-ms N]');
}
const suite = options['--suite'];
assert.ok(['equality', 'composition'].includes(suite), 'Specify --suite equality or composition');
assert.ok(options['--input'], 'Specify --input FILE');
const input = path.resolve(options['--input']);
// Read before replacing artifacts; never modify the original failure input.
let source;
let parseError;
try {
  assert.ok(fs.statSync(input).size <= 4 * 1024 * 1024, 'Failure file exceeds 4 MiB');
  source = JSON.parse(fs.readFileSync(input, 'utf8'));
} catch (e) { parseError = e; }
const mode = options['--release'] || source?.mode === 'release' ? 'release' : 'debug';
const outputDir = path.resolve(options['--output-dir'] || path.join(root, '_build'));
const report = path.join(outputDir, `minimize-${suite}-${mode}-summary.json`);
const output = path.join(outputDir, `${suite}-${mode}-minimized.json`);
const samePath = (a, b) => {
  const real = p => fs.existsSync(p) ? fs.realpathSync(p) : path.resolve(p);
  return process.platform === 'win32' ? real(a).toLowerCase() === real(b).toLowerCase() : real(a) === real(b);
};
assert.ok(!samePath(input, output) && !samePath(input, report), 'Input must differ from generated output/report; copy it to a new name first');
fs.mkdirSync(path.dirname(report), {recursive: true});
fs.rmSync(report, {force: true});
fs.rmSync(output, {force: true});
function integer(key, fallback, min, max) {
  const n = options[key] === undefined ? fallback : Number(options[key]);
  assert.ok(Number.isSafeInteger(n) && n >= min && n <= max, 'Invalid ' + key);
  return n;
}
try {
  if (parseError) throw parseError;
  assert.ok(!source?.mode || ['debug', 'release'].includes(source.mode), 'Invalid build mode');
  const maxAttempts = integer('--max-attempts', 100, 2, 1000);
  const maxMs = integer('--max-ms', 60000, 1, 120000);
  const timeout = integer('--timeout-ms', 15000, 1, 15000);
  // Validate depth iteratively before recursive oracle/candidate processing.
  const stack = [[source, 0]];
  let nodes = 0;
  while (stack.length) {
    const [x, depth] = stack.pop();
    assert.ok(++nodes <= 100000 && depth <= 128, 'Failure data exceeds reducer structural limits');
    if (typeof x === 'number') assert.ok(Number.isFinite(x), 'Nonfinite input number');
    if (x !== null && typeof x === 'object') for (const v of Object.values(x)) stack.push([v, depth + 1]);
  }
  assert.ok(Array.isArray(source?.cases) && source.cases.length > 0 && source.cases.length <= 250, 'Expected 1–250 saved cases');
  const oracle = (c, data) => expectedFor(suite, c, data);
  let opaqueCases = 0;
  for (const c of source.cases) {
    assert.ok(c && typeof c.expression === 'string' && c.expression.length <= 16384 && Object.hasOwn(c, 'data'), 'Invalid request');
    assert.notEqual(Object.hasOwn(c, 'result'), Object.hasOwn(c, 'error'), 'Expected exactly one result/error');
    if (Object.hasOwn(c, 'error')) assert.equal(c.error, 'invalid_type');
    if (suite === 'equality') assert.equal(typeof c.result, 'boolean');
    const expected = oracle(c, c.data);
    if (expected) assert.deepEqual(expected, Object.hasOwn(c, 'error') ? {error: c.error} : {result: c.result}, 'Saved expectation disagrees with independent oracle');
    else opaqueCases++;
  }
  const cli = path.resolve(process.env.JMES_CLI_PATH || path.join(root, `_build/js/${mode}/build/cmd/main/main.js`));
  assert.ok(fs.statSync(cli).isFile(), 'CLI artifact must be a file');
  const probe = cases => {
    const r = spawnSync(process.execPath, ['--max-old-space-size=192', cli, '--batch', '--compact', '-'], {
      cwd: root, input: JSON.stringify(cases.map(({expression, data}) => ({expression, data}))),
      encoding: 'utf8', timeout, maxBuffer: 8 * 1024 * 1024,
    });
    if (r.error?.code === 'ETIMEDOUT') return 'process:timeout';
    if (r.error?.code === 'ENOBUFS') return 'process:output-limit';
    if (r.error) throw r.error;
    if (r.status !== 0) return `process:exit:${r.status}:signal:${r.signal}`;
    if (r.stderr) return 'protocol:stderr';
    let responses;
    try { responses = JSON.parse(r.stdout); } catch { return 'protocol:json'; }
    return responseSignature(cases, responses);
  };
  const reduced = minimizeCases(source.cases, {probe, oracle, maxAttempts, maxMs, reserveMs: timeout});
  const {cases, ...receipt} = reduced;
  const reproduced = ['reduced', 'unchanged'].includes(receipt.status);
  if (reproduced) fs.writeFileSync(output, JSON.stringify({schemaVersion: 1, suite, mode,
    signature: receipt.signature, cases}, null, 2) + '\n');
  fs.writeFileSync(report, JSON.stringify({...receipt, suite, mode, input, output: reproduced ? output : null,
    opaqueCases, maxAttempts, maxMs, timeoutMs: timeout, cli, node: process.version,
    recordedAt: new Date().toISOString()}, null, 2) + '\n');
  console.log('MINIMIZE_SUMMARY ' + JSON.stringify(receipt));
  if (reproduced) console.log(`Replay: node "${path.join(root, 'scripts', `${suite}-properties.mjs`)}" ${mode === 'release' ? '--release ' : ''}--replay "${output}"`);
  // Zero means a confirmed reproducer was saved, not that the library passed.
  process.exitCode = reproduced ? 0 : 2;
} catch (error) {
  fs.writeFileSync(report, JSON.stringify({status: 'failed', suite, mode, error: String(error.message).slice(0, 1200),
    output: null, recordedAt: new Date().toISOString()}, null, 2) + '\n');
  console.error(String(error.message).slice(0, 1200));
  process.exitCode = 1;
}
