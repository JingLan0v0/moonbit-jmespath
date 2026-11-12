import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { runConformanceCheck } from './lib/conformance-report.mjs';
import { revision } from './lib/conformance-vectors.mjs';

function makeFixture(t) {
  const temp = fs.realpathSync(os.tmpdir());
  const fixture = fs.mkdtempSync(path.join(temp, 'moonjmes-report-test-'));
  t.after(() => {
    assert.equal(path.dirname(fs.realpathSync(fixture)), temp);
    assert.ok(path.basename(fixture).startsWith('moonjmes-report-test-'));
    fs.rmSync(fixture, { recursive: true, force: true });
  });

  const project = path.resolve(import.meta.dirname, '..');
  for (const file of [
    'scripts/verify.mjs', 'scripts/conformance.mjs', 'examples/demo.mjs',
    'scripts/lib/conformance-report.mjs', 'scripts/lib/conformance-vectors.mjs',
    'scripts/lib/write-json.mjs',
  ]) {
    const destination = path.join(fixture, file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(project, file), destination);
  }
  return fixture;
}

function runScript(fixture, args, env = {}) {
  const child = spawnSync(process.execPath, args, {
    cwd: fixture, encoding: 'utf8', timeout: 15_000, env: { ...process.env, ...env },
  });
  if (child.error) throw child.error;
  return child;
}

test('a source-check failure removes stale suite evidence', t => {
  const fixture = makeFixture(t);
  const build = path.join(fixture, '_build');
  fs.mkdirSync(build);
  const owned = ['moon-version.txt'];
  for (const mode of ['debug', 'release']) {
    for (const suite of ['conformance', 'equality', 'composition']) {
      owned.push(suite + '-' + mode + '-summary.json');
    }
    for (const suite of ['equality', 'composition']) {
      owned.push(suite + '-' + mode + '-failure.json');
    }
  }
  const retained = ['benchmark-release-summary.json', 'composition-debug-minimized.json'];
  for (const file of [...owned, ...retained, 'verification-summary.json']) {
    fs.writeFileSync(path.join(build, file), '{"status":"passed","stale":true}\n');
  }

  const child = runScript(fixture, ['scripts/verify.mjs'], { GIT_DIR: path.join(fixture, 'missing-git-directory') });
  assert.equal(child.status, 1, child.stderr);
  assert.match(child.stderr, /failed: source:/);
  for (const file of owned) assert.equal(fs.existsSync(path.join(build, file)), false, file);
  for (const file of retained) {
    assert.equal(fs.readFileSync(path.join(build, file), 'utf8'), '{"status":"passed","stale":true}\n');
  }
  const report = JSON.parse(fs.readFileSync(path.join(build, 'verification-summary.json'), 'utf8'));
  assert.equal(report.stale, undefined);
  assert.equal(report.status, 'failed');
  assert.equal(report.source, null);
  assert.equal(report.steps.find(step => step.id === 'prepare-reports')?.status, 'passed');
  assert.equal(report.steps.find(step => step.id === 'source')?.status, 'failed');
  assert.equal(report.steps.find(step => step.id === 'toolchain')?.status, 'not_run');
});

test('an output limit keeps bounded diagnostics from both streams', t => {
  const fixture = makeFixture(t);
  for (const args of [
    ['init', '--quiet'],
    ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false',
      'commit', '--allow-empty', '--quiet', '-m', 'fixture'],
  ]) {
    const result = spawnSync('git', args, { cwd: fixture, encoding: 'utf8', timeout: 5_000 });
    if (result.error) throw result.error;
    assert.equal(result.status, 0, result.stderr);
  }
  fs.writeFileSync(path.join(fixture, 'version'), `
    const { writeSync } = require('node:fs');
    writeSync(1, 'tool stdout excerpt\\n');
    writeSync(2, 'tool stderr excerpt\\n'.repeat(110_000));
  `);

  const child = runScript(fixture, ['scripts/verify.mjs'], { MOON_BIN: process.execPath });
  assert.equal(child.status, 1, child.stderr);
  assert.ok(child.stderr.length < 4_000);
  const report = JSON.parse(fs.readFileSync(path.join(fixture, '_build', 'verification-summary.json'), 'utf8'));
  assert.equal(report.status, 'failed');
  const toolchain = report.steps.find(step => step.id === 'toolchain');
  assert.equal(toolchain.status, 'failed');
  for (const diagnostic of [/ENOBUFS/, /tool stdout excerpt/, /tool stderr excerpt/]) {
    assert.match(toolchain.error, diagnostic);
    assert.match(child.stderr, diagnostic);
  }
  assert.equal(report.steps.find(step => step.id === 'format')?.status, 'not_run');
});

test('a damaged conformance report cannot hide the subprocess failure', t => {
  const fixture = makeFixture(t);
  const reportPath = path.join(fixture, 'conformance-debug-summary.json');
  const options = { mode: 'debug', artifact: 'debug/main.js', reportPath };
  const failure = Object.assign(new Error('conformance subprocess failed: download ended early'), { exitCode: 3 });
  const run = () => { throw failure; };
  for (const content of [
    undefined, '{"status":',
    JSON.stringify({ status: 'network_blocked', mode: 'debug', revision }),
  ]) {
    if (content !== undefined) fs.writeFileSync(reportPath, content);
    assert.throws(() => runConformanceCheck(run, options), error => {
      assert.equal(error.cause, failure);
      assert.notEqual(error.exitCode, 3);
      assert.match(error.message, /download ended early/);
      assert.match(error.message, /conformance-debug-summary\.json/);
      return true;
    });
  }
});

test('a matching conformance report preserves the network-blocked result', t => {
  const fixture = makeFixture(t);
  const reportPath = path.join(fixture, 'conformance-release-summary.json');
  const counts = { revision, total: null, passed: null };
  fs.writeFileSync(reportPath, JSON.stringify({ mode: 'release', status: 'network_blocked', ...counts }));
  const failure = Object.assign(new Error('both downloads unavailable'), { exitCode: 3 });
  assert.throws(() => runConformanceCheck((command, args) => {
    assert.equal(command, process.execPath);
    assert.deepEqual(args, ['scripts/conformance.mjs', '--cli', 'release/main.js', '--release']);
    throw failure;
  }, { mode: 'release', artifact: 'release/main.js', reportPath }), error => {
    assert.equal(error, failure);
    assert.equal(error.exitCode, 3);
    assert.deepEqual(error.details, counts);
    return true;
  });
});

test('success requires the expected conformance status, mode, revision, and counts', t => {
  const fixture = makeFixture(t);
  const reportPath = path.join(fixture, 'conformance-debug-summary.json');
  const options = { mode: 'debug', artifact: 'debug/main.js', reportPath };
  const counts = { revision, total: 892, passed: 892 };
  const summary = { status: 'passed', mode: 'debug', ...counts };
  for (const override of [{ status: 'failed' }, { mode: 'release' }, { revision: 'stale' }, { passed: 891 }]) {
    fs.writeFileSync(reportPath, JSON.stringify({ ...summary, ...override }));
    assert.throws(() => runConformanceCheck(() => '', options), /Invalid conformance/);
  }
  fs.writeFileSync(reportPath, JSON.stringify(summary));
  assert.deepEqual(runConformanceCheck(() => '', options), counts);
});

test('a failed verification report replacement keeps the prior report and removes its temporary file', t => {
  const fixture = makeFixture(t);
  const build = path.join(fixture, '_build');
  fs.mkdirSync(build);
  const name = 'verification-summary.json';
  const prior = '{"status":"passed","prior":true}\n';
  fs.writeFileSync(path.join(build, name), prior);
  fs.writeFileSync(path.join(fixture, 'busy-report.mjs'), `
    import fs from 'node:fs';
    import path from 'node:path';
    const rename = fs.renameSync;
    fs.renameSync = (from, to) => {
      if (path.basename(to) === '${name}') throw new Error('simulated busy report');
      return rename(from, to);
    };
  `);
  const child = runScript(fixture, ['--import', './busy-report.mjs', 'scripts/verify.mjs']);
  assert.equal(child.status, 1, child.stderr);
  assert.match(child.stderr, /simulated busy report/);
  assert.equal(fs.readFileSync(path.join(build, name), 'utf8'), prior);
  assert.deepEqual(fs.readdirSync(build), [name]);

  const retry = runScript(fixture, ['scripts/verify.mjs'], { GIT_DIR: path.join(fixture, 'missing-git-directory') });
  assert.equal(retry.status, 1, retry.stderr);
  const report = JSON.parse(fs.readFileSync(path.join(build, name), 'utf8'));
  assert.equal(report.status, 'failed');
  assert.equal(report.prior, undefined);
  assert.deepEqual(fs.readdirSync(build), [name]);
});

test('a failed conformance report write leaves no partial report', t => {
  const fixture = makeFixture(t);
  fs.writeFileSync(path.join(fixture, 'partial-report.mjs'), `
    import fs from 'node:fs';
    import path from 'node:path';
    const write = fs.writeFileSync;
    fs.writeFileSync = (file, ...args) => {
      if (path.basename(file).startsWith('conformance-debug-summary.json')) {
        write(file, '{"status":');
        throw new Error('simulated partial write');
      }
      return write(file, ...args);
    };
  `);
  const child = runScript(fixture, [
    '--import', './partial-report.mjs', 'scripts/conformance.mjs', '--cli', 'missing-cli.js',
  ]);
  assert.equal(child.status, 1, child.stderr);
  assert.match(child.stderr, /Missing CLI artifact/);
  assert.match(child.stderr, /simulated partial write/);
  assert.deepEqual(fs.readdirSync(path.join(fixture, '_build')), []);
});
