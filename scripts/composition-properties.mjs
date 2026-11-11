import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { cases, initialSeed, expressions, coverage, generatedQueries, fixtures, corpusHash } from './lib/composition-corpus.mjs';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const args = process.argv.slice(2);
let mode = 'debug';
let replayPath;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--release' && mode === 'debug') mode = 'release';
  else if (args[i] === '--replay' && !replayPath && args[i + 1]) replayPath = path.resolve(args[++i]);
  else throw new Error('Usage: node scripts/composition-properties.mjs [--release] [--replay FILE]');
}
const cli = process.env.JMES_CLI_PATH || path.join(root, `_build/js/${mode}/build/cmd/main/main.js`);
const report = path.join(root, `_build/composition-${mode}-summary.json`);
const failure = path.join(root, `_build/composition-${mode}-failure.json`);
fs.mkdirSync(path.dirname(report), {recursive: true});
fs.rmSync(report, {force: true});
let passed = 0, active = [], batchStart = 0;
try {
  // Read before removing: replay may point to the failure file itself.
  const selected = replayPath ? JSON.parse(fs.readFileSync(replayPath, 'utf8')).cases : cases;
  assert.ok(Array.isArray(selected) && selected.length > 0 && selected.length <= cases.length, 'Invalid replay cases');
  for (const c of selected) {
    assert.equal(typeof c.expression, 'string');
    assert.ok(Object.hasOwn(c, 'data'));
    assert.notEqual(Object.hasOwn(c, 'result'), Object.hasOwn(c, 'error'));
    if (Object.hasOwn(c, 'error')) assert.equal(c.error, 'invalid_type');
  }
  fs.rmSync(failure, {force: true});
  for (let start = 0; start < selected.length; start += 250) {
    active = selected.slice(start, start + 250);
    batchStart = start;
    const r = spawnSync(process.execPath, ['--max-old-space-size=192', cli, '--batch', '--compact', '-'], {
      cwd: root, input: JSON.stringify(active.map(({expression, data}) => ({expression, data}))),
      encoding: 'utf8', timeout: 15000, maxBuffer: 8 * 1024 * 1024,
    });
    assert.ifError(r.error);
    assert.equal(r.status, 0, (r.stderr || '').slice(0, 1024));
    assert.equal(r.stderr, '');
    const got = JSON.parse(r.stdout);
    assert.ok(Array.isArray(got));
    assert.equal(got.length, active.length);
    const chunk = active;
    for (let i = 0; i < chunk.length; i++) {
      active = [chunk[i]];
      if (Object.hasOwn(chunk[i], 'error')) {
        assert.equal(got[i].ok, false, `case ${start + i}`);
        assert.equal(got[i].error.code, chunk[i].error, `case ${start + i}`);
      } else assert.deepEqual(got[i], {ok: true, result: chunk[i].result}, `case ${start + i}`);
      passed++;
    }
  }
} catch (error) {
  // Invalid replay input is a setup failure; preserve its original contents.
  if (active.length) fs.writeFileSync(failure, JSON.stringify({schemaVersion: 1, mode, seed: initialSeed, corpusHash, batchStart, passed, cases: active}, null, 2) + '\n');
  fs.writeFileSync(report, JSON.stringify({status: 'failed', mode, passed, failure: active.length ? failure : null,
    error: String(error.message).slice(0, 1200), recordedAt: new Date().toISOString()}, null, 2) + '\n');
  console.error(`FAIL composition ${mode}: ${String(error.message).slice(0, 1200)}`);
  process.exit(1);
}
const counts = {queries: passed, generatedQueries: replayPath ? null : generatedQueries,
  normativeQueries: replayPath ? null : fixtures.length, expressions: replayPath ? null : expressions.size,
  seed: initialSeed, corpusHash, coverage: replayPath ? null : coverage};
fs.writeFileSync(report, JSON.stringify({status: 'passed', mode, ...counts, replay: replayPath || null,
  cli: path.relative(root, cli), node: process.version, ciCommit: process.env.GITHUB_SHA || null,
  recordedAt: new Date().toISOString()}, null, 2) + '\n');
console.log(`PASS composition ${mode}: ${passed} queries`);
console.log('COMPOSITION_SUMMARY ' + JSON.stringify(counts));
