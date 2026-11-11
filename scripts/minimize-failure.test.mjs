import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {spawnSync} from 'node:child_process';
import {isDeepStrictEqual} from 'node:util';
import {minimizeCases, responseSignature, shrinkJson} from './lib/failure-reducer.mjs';
import {expectedFor} from './lib/case-oracle.mjs';
import {corpusHash, cases as corpus} from './lib/composition-corpus.mjs';

const root = path.resolve(import.meta.dirname, '..');
const oracle = (c, data) => expectedFor('equality', c, data);
const witness = JSON.parse(fs.readFileSync(path.join(root, 'scripts/fixtures/reducer-type-regression.json'), 'utf8'));
const bug = cases => responseSignature(cases, cases.map(c => {
  const result = oracle(c, c.data).result;
  return {ok: true, result: c.data.left === true && c.data.right === 1 ? true : result};
}));

test('independent corpus is unchanged by extraction', () => {
  assert.equal(corpusHash, 'e7124f3752d663692fb5111742f09910a0c00999e54f78c4416f73ce71abf4d4');
  assert.equal(corpus.length, 8207);
});
test('reduces injected bool/number defect to a permanent fixture', () => {
  const original = [{...witness.cases[0], data: {left: true, right: 1, noise: 'padding'.repeat(100)}}];
  const r = minimizeCases(original, {probe: bug, oracle});
  assert.equal(r.status, 'reduced');
  assert.deepEqual(r.cases, witness.cases);
  assert.ok(original[0].data.noise, 'original data was mutated');
  assert.equal(r.signature, 'value-mismatch:left == right');
});
test('retains ordered neighbors needed to reproduce a process failure', () => {
  const original = ['unused', 'trigger', 'middle', 'victim', 'tail'].map(expression => ({expression, data: null, result: null}));
  const probe = cases => {
    const names = cases.map(c => c.expression);
    return names.indexOf('trigger') >= 0 && names.indexOf('victim') > names.indexOf('trigger') ? 'process:exit:1' : 'process:timeout';
  };
  const r = minimizeCases(original, {probe, oracle: () => null});
  assert.deepEqual(r.cases.map(c => c.expression), ['trigger', 'victim']);
  assert.equal(r.signature, 'process:exit:1');
});
test('does not replace a value mismatch with an error or timeout', () => {
  const c = [{expression: '@', data: 'x', result: 'x'}];
  const r = minimizeCases(c, {oracle: (_c, data) => ({result: data}), probe: xs => xs[0].data === 'x' ? 'value-mismatch:@' : 'process:timeout'});
  assert.deepEqual(r.cases, c);
});
test('recomputes expectations when data changes', () => {
  const c = [{expression: '@', data: 'long string', result: 'long string'}];
  const r = minimizeCases(c, {oracle: (_c, data) => ({result: data}), probe: xs => {
    assert.deepEqual(xs[0].result, xs[0].data);
    return 'value-mismatch:@';
  }});
  assert.equal(r.status, 'reduced');
  assert.equal(r.cases[0].data, null);
  assert.equal(r.cases[0].result, null);
});
test('does not edit data of an opaque normative fixture', () => {
  const c = [{expression: 'unknown()', data: [1, 2, 3], error: 'invalid_type'}];
  const r = minimizeCases(c, {oracle: () => null, probe: () => 'wrong-error:invalid_type:syntax_error'});
  assert.deepEqual(r.cases, c);
  assert.equal(r.status, 'unchanged');
});
test('rejects nonreproduction and unstable original failures', () => {
  assert.equal(minimizeCases(witness.cases, {oracle, probe: () => null}).status, 'not_reproduced');
  let calls = 0;
  assert.equal(minimizeCases(witness.cases, {oracle, probe: () => ++calls === 1 ? 'bug' : null}).status, 'unstable');
});
test('candidate failure must reproduce twice', () => {
  const c = [{expression: '@', data: 'abc', result: 'abc'}];
  const counts = new Map();
  const r = minimizeCases(c, {oracle: (_c, data) => ({result: data}), probe: xs => {
    const key = JSON.stringify(xs);
    counts.set(key, (counts.get(key) || 0) + 1);
    return isDeepStrictEqual(xs, c) || counts.get(key) % 2 === 1 ? 'bug' : null;
  }});
  assert.equal(r.status, 'unchanged');
});
test('enforces attempt and time budgets without changing timeout thresholds', () => {
  const c = [{...witness.cases[0], data: {left: true, right: 1, noise: 'padding'}}];
  const r = minimizeCases(c, {oracle, probe: bug, maxAttempts: 2});
  assert.equal(r.attempts, 2);
  assert.equal(r.stopReason, 'attempt_limit');
  const t = minimizeCases(c, {oracle, probe: () => {throw new Error('must not run');}, now: () => 0, reserveMs: 100, maxMs: 199});
  assert.equal(t.status, 'budget_exhausted');
  assert.equal(t.stopReason, 'time_limit');
});
test('failure signatures distinguish error categories and malformed responses', () => {
  assert.equal(responseSignature(witness.cases, [{ok: true, result: false}]), null);
  assert.equal(responseSignature(witness.cases, [{ok: false, error: {code: 'syntax_error'}}]), 'unexpected-error:syntax_error:left == right');
  assert.equal(responseSignature(witness.cases, [null]), 'protocol:item-shape');
  const errors = [{expression: 'merge(a,b)', data: {}, error: 'invalid_type'}];
  assert.equal(responseSignature(errors, [{ok: false, error: {code: 'invalid_type'}}]), null);
  assert.match(responseSignature(errors, [{ok: false, error: {code: 'syntax_error'}}]), /^wrong-error:invalid_type:syntax_error:/);
  assert.match(responseSignature(errors, [{ok: true, result: null}]), /^missing-error:invalid_type:/);
});
test('shrinking preserves Unicode scalars and own prototype-named keys', () => {
  for (const x of shrinkJson('😀é')) if (typeof x === 'string') assert.ok(x.isWellFormed());
  const c = JSON.parse('{"__proto__":{"a":1},"constructor":"xyz"}');
  const candidates = [...shrinkJson(c)];
  assert.ok(candidates.some(x => x && Object.hasOwn(x, '__proto__') && x.__proto__ === null));
  assert.equal(Object.getPrototypeOf(c).a, undefined);
});

test('CLI saves only confirmed reproducers, replays them and clears stale artifacts', () => {
  const tempBase = fs.realpathSync(os.tmpdir());
  const temp = fs.mkdtempSync(path.join(tempBase, 'moonjmes-reducer-'));
  const mode = process.env.JMES_REDUCER_TEST_MODE || 'debug';
  const input = path.join(temp, 'input.json');
  const fake = path.join(temp, 'fake.cjs');
  const outputDir = path.join(temp, 'out');
  const output = path.join(outputDir, `equality-${mode}-minimized.json`);
  const report = path.join(outputDir, `minimize-equality-${mode}-summary.json`);
  const cli = process.env.JMES_CLI_PATH || path.join(root, `_build/js/${mode}/build/cmd/main/main.js`);
  const run = (artifact, extra = []) => spawnSync(process.execPath, [path.join(root, 'scripts/minimize-failure.mjs'),
    '--suite', 'equality', '--input', input, '--output-dir', outputDir, ...(mode === 'release' ? ['--release'] : []), ...extra],
  {cwd: temp, env: {...process.env, JMES_CLI_PATH: artifact}, encoding: 'utf8', timeout: 30000});
  const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
  try {
    fs.writeFileSync(input, JSON.stringify({cases: [{...witness.cases[0], data: {left: true, right: 1, noise: 'padding'.repeat(50)}}]}));
    const original = fs.readFileSync(input, 'utf8');
    fs.writeFileSync(fake, `const fs=require('node:fs');const cases=JSON.parse(fs.readFileSync(0,'utf8'));console.log(JSON.stringify(cases.map(c=>({ok:true,result:c.data.left===true&&c.data.right===1?true:JSON.stringify(c.data.left??null)===JSON.stringify(c.data.right??null)}))));`);
    let r = run(fake);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(read(report).status, 'reduced');
    assert.deepEqual(read(output).cases, witness.cases);
    assert.equal(fs.readFileSync(input, 'utf8'), original);
    const replay = artifact => spawnSync(process.execPath, [path.join(root, 'scripts/equality-properties.mjs'),
      ...(mode === 'release' ? ['--release'] : []), '--replay', output],
    {cwd: temp, env: {...process.env, JMES_CLI_PATH: artifact}, encoding: 'utf8', timeout: 30000});
    assert.equal(replay(fake).status, 1);
    assert.equal(replay(cli).status, 0);
    r = run(cli);
    assert.equal(r.status, 2, r.stderr);
    assert.equal(read(report).status, 'not_reproduced');
    assert.equal(fs.existsSync(output), false);
    r = run(fake, ['--max-attempts', '2']);
    assert.equal(r.status, 0, r.stderr);
    assert.equal(read(report).stopReason, 'attempt_limit');
    r = run(path.join(temp, 'missing.cjs'));
    assert.equal(r.status, 1);
    assert.equal(read(report).status, 'failed');
    assert.equal(fs.existsSync(output), false);
    fs.writeFileSync(input, '{bad JSON');
    r = run(cli);
    assert.equal(r.status, 1);
    assert.equal(read(report).status, 'failed');
    assert.equal(fs.readFileSync(input, 'utf8'), '{bad JSON');
    fs.writeFileSync(input, JSON.stringify({cases: [{...witness.cases[0], result: true}]}));
    r = run(fake);
    assert.equal(r.status, 1);
    assert.match(read(report).error, /Saved expectation disagrees/);
    // Composition shrinking uses its generated evaluator, not stale fixtures.
    const generated = corpus.find(c => c.category === 'type');
    const data = {a: [1, 2], b: 'x', noise: 'padding'.repeat(100)};
    fs.writeFileSync(input, JSON.stringify({cases: [{...generated, data, ...expectedFor('composition', generated, data)}]}));
    fs.writeFileSync(fake, `const fs=require('node:fs');const a=JSON.parse(fs.readFileSync(0,'utf8'));console.log(JSON.stringify(a.map(()=>({ok:true,result:'injected defect'}))));`);
    r = spawnSync(process.execPath, [path.join(root, 'scripts/minimize-failure.mjs'), '--suite', 'composition',
      '--input', input, '--output-dir', outputDir, ...(mode === 'release' ? ['--release'] : [])],
    {cwd: temp, env: {...process.env, JMES_CLI_PATH: fake}, encoding: 'utf8', timeout: 30000});
    assert.equal(r.status, 0, r.stderr);
    const compositionOutput = path.join(outputDir, `composition-${mode}-minimized.json`);
    const minimized = read(compositionOutput).cases[0];
    assert.equal(minimized.data, null);
    assert.deepEqual({result: minimized.result}, expectedFor('composition', minimized, minimized.data));
    for (const artifact of [fake, cli]) {
      r = spawnSync(process.execPath, [path.join(root, 'scripts/composition-properties.mjs'),
        ...(mode === 'release' ? ['--release'] : []), '--replay', compositionOutput],
      {cwd: temp, env: {...process.env, JMES_CLI_PATH: artifact}, encoding: 'utf8', timeout: 30000});
      assert.equal(r.status, artifact === fake ? 1 : 0, r.stderr);
    }
  } finally {
    assert.equal(path.dirname(temp), tempBase);
    assert.ok(path.basename(temp).startsWith('moonjmes-reducer-'));
    fs.rmSync(temp, {recursive: true, force: true});
  }
});
