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
    'scripts/verify.mjs', 'scripts/conformance.mjs', 'scripts/benchmark.mjs', 'scripts/moon.ps1',
    'examples/demo.mjs', 'toolchain.json',
    'scripts/lib/conformance-report.mjs', 'scripts/lib/conformance-vectors.mjs',
    'scripts/lib/write-json.mjs', 'scripts/lib/built-artifact.mjs',
  ]) {
    const destination = path.join(fixture, file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(project, file), destination);
  }
  return fixture;
}

function runScript(fixture, args, env = {}) {
  const child = spawnSync(process.execPath, args, {
    cwd: fixture, encoding: 'utf8', timeout: 15_000, env: { ...process.env, GITHUB_SHA: '', ...env },
  });
  if (child.error) throw child.error;
  return child;
}

test('the PowerShell wrapper distinguishes inherited stdin from pipeline input',
  { skip: process.platform !== 'win32' }, t => {
    const fixture = makeFixture(t);
    const probe = path.join(fixture, 'read-stdin.cjs');
    fs.writeFileSync(probe, "console.log(JSON.stringify(require('node:fs').readFileSync(0, 'utf8')));\n");
    const invocation = '& $env:MOONJMES_TEST_WRAPPER $env:MOONJMES_STDIN_PROBE';
    for (const shell of ['powershell.exe', 'pwsh']) {
      for (const [pipeline, expected] of [
        ['', 'inherited stdin'],
        ['@() | ', ''],
        ["'' | ", '\r\n'],
        ["@('first','second') | ", 'first\r\nsecond\r\n'],
      ]) {
        const child = spawnSync(shell, ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
          '-Command', pipeline + invocation + '; exit $LASTEXITCODE'], {
          cwd: fixture, input: 'inherited stdin', encoding: 'utf8', timeout: 15_000,
          env: {
            ...process.env, MOON_BIN: process.execPath,
            MOONJMES_TEST_WRAPPER: path.join(fixture, 'scripts/moon.ps1'),
            MOONJMES_STDIN_PROBE: probe,
          },
        });
        if (child.error) throw child.error;
        assert.equal(child.status, 0, child.stderr);
        assert.equal(JSON.parse(child.stdout), expected, shell + ' ' + (pipeline || 'direct invocation'));
      }
    }
  });

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

function initializeCheckout(fixture) {
  for (const args of [
    ['init', '--quiet'],
    ['-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', '-c', 'commit.gpgsign=false',
      'commit', '--allow-empty', '--quiet', '-m', 'fixture'],
  ]) {
    const result = spawnSync('git', args, { cwd: fixture, encoding: 'utf8', timeout: 5_000 });
    if (result.error) throw result.error;
    assert.equal(result.status, 0, result.stderr);
  }
}

test('CI verifies the expected checkout before running the toolchain', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
  const exclude = path.join(fixture, '.git', 'info', 'exclude');
  fs.appendFileSync(exclude, '\n/scripts/\n/examples/\n/toolchain.json\n/_build/\n');
  const head = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: fixture, encoding: 'utf8', timeout: 5_000 });
  if (head.error) throw head.error;
  assert.equal(head.status, 0, head.stderr);
  const actual = head.stdout.trim();
  const mismatched = '11'.repeat(actual.length / 2);
  assert.notEqual(actual, mismatched);
  const missingMoon = path.join(fixture, 'missing-moon');
  const summary = path.join(fixture, '_build', 'verification-summary.json');

  const cases = [
    { ciCommit: mismatched, dirty: false, sourceError: /HEAD does not match GITHUB_SHA/ },
    { ciCommit: actual, dirty: false },
    { ciCommit: actual, dirty: true, sourceError: /CI requires a clean working tree/ },
    { ciCommit: '', dirty: true },
  ];
  for (const { ciCommit, dirty, sourceError } of cases) {
    if (dirty) fs.writeFileSync(path.join(fixture, 'untracked.mbt'), '// local work\n');
    const child = runScript(fixture, ['scripts/verify.mjs'], { GITHUB_SHA: ciCommit, MOON_BIN: missingMoon });
    assert.equal(child.status, 1, child.stderr);
    const report = JSON.parse(fs.readFileSync(summary, 'utf8'));
    assert.equal(report.status, 'failed');
    assert.deepEqual(report.source, { sha: actual, dirty });
    assert.equal(report.ciCommit, ciCommit || null);
    const source = report.steps.find(step => step.id === 'source');
    const toolchain = report.steps.find(step => step.id === 'toolchain');
    if (sourceError) {
      assert.equal(source.status, 'failed');
      assert.match(source.error, sourceError);
      assert.equal(toolchain.status, 'not_run');
    } else {
      assert.equal(source.status, 'passed');
      assert.equal(toolchain.status, 'failed');
      assert.match(toolchain.error, /ENOENT/);
    }
  }
});

test('an output limit keeps bounded diagnostics from both streams', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
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

test('verification identifies version drift and the pinned run stops before formatting', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
  const expected = JSON.parse(fs.readFileSync(path.join(fixture, 'toolchain.json'), 'utf8'));
  const banner = [
    `moon ${expected.moon} /toolchains/pinned/bin/moon`,
    'moonc v0.10.14+7d59c7ec9 (2026-09-18) /toolchains/older/bin/moonc',
  ].join('\n');
  fs.writeFileSync(path.join(fixture, 'version'), `console.log(${JSON.stringify(banner)});\n`);
  fs.writeFileSync(path.join(fixture, 'fmt'), "console.error('format was reached'); process.exitCode = 1;\n");
  const build = path.join(fixture, '_build');

  for (const pinned of [true, false]) {
    const result = runScript(fixture, ['scripts/verify.mjs'], {
      MOON_BIN: process.execPath,
      JMES_VERIFY_PINNED_TOOLCHAIN: pinned ? '1' : '',
    });
    assert.equal(result.status, 1, result.stderr);
    const report = JSON.parse(fs.readFileSync(path.join(build, 'verification-summary.json'), 'utf8'));
    assert.equal(report.toolchain, banner);
    assert.equal(fs.readFileSync(path.join(build, 'moon-version.txt'), 'utf8'), banner + '\n');
    const toolchain = report.steps.find(step => step.id === 'toolchain');
    assert.equal(toolchain.status, pinned ? 'failed' : 'passed');
    assert.match(result.stderr, /moonc differs from toolchain\.json/);
    assert.match(result.stderr, /v0\.10\.14\+7d59c7ec9/);
    assert.equal(report.steps.find(step => step.id === 'format')?.status, pinned ? 'not_run' : 'failed');
    if (!pinned) {
      assert.equal(toolchain.details.matchesPinnedVersions, false);
      assert.match(toolchain.details.differences[0], /moonc differs/);
    }
  }
});

test('a successful build must produce a nonempty CLI for the current run', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
  const expected = JSON.parse(fs.readFileSync(path.join(fixture, 'toolchain.json'), 'utf8'));
  const outputs = {
    version: `moon ${expected.moon}\nmoonc ${expected.moonc}`,
    test: 'Total tests: 1, passed: 1',
    run: '["Ada"]\n[]\nerror: invalid_type',
  };
  for (const [command, output] of Object.entries(outputs)) {
    fs.writeFileSync(path.join(fixture, command), `console.log(${JSON.stringify(output)});\n`);
  }
  for (const command of ['fmt', 'check', 'info']) fs.writeFileSync(path.join(fixture, command), '');
  const buildDir = path.join(fixture, '_build');
  const artifact = path.join(buildDir, 'js/debug/build/cmd/main/main.js');
  fs.mkdirSync(path.dirname(artifact), { recursive: true });

  for (const buildProgram of ['', `require('node:fs').writeFileSync(${JSON.stringify(artifact)}, '');`]) {
    fs.writeFileSync(artifact, 'console.log("left from an earlier run");\n');
    fs.writeFileSync(path.join(fixture, 'build'), buildProgram);
    const result = runScript(fixture, ['scripts/verify.mjs'], {
      MOON_BIN: process.execPath, JMES_VERIFY_PINNED_TOOLCHAIN: '',
    });
    assert.equal(result.status, 1, result.stderr);
    const report = JSON.parse(fs.readFileSync(path.join(buildDir, 'verification-summary.json'), 'utf8'));
    const build = report.steps.find(step => step.id === 'build-cli' && step.mode === 'debug');
    assert.equal(build.status, 'failed');
    assert.match(build.error, /Build did not produce a nonempty CLI artifact/);
    assert.equal(report.steps.find(step => step.id === 'scenarios' && step.mode === 'debug')?.status, 'not_run');
  }
});

test('a benchmark cannot time artifacts left by an earlier build', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
  const build = path.join(fixture, '_build');
  const bench = path.join(build, 'js/release/build/bench/bench.js');
  const cli = path.join(build, 'js/release/build/cmd/main/main.js');
  const stale = "require('node:fs').writeFileSync('stale-executed', 'ran');\n";
  fs.writeFileSync(path.join(fixture, 'version'), "console.log('toolchain fixture');\n");

  for (const { freshBench, label } of [
    { freshBench: false, label: 'benchmark harness' },
    { freshBench: true, label: 'CLI' },
  ]) {
    for (const artifact of [bench, cli]) {
      fs.mkdirSync(path.dirname(artifact), { recursive: true });
      fs.writeFileSync(artifact, stale);
    }
    fs.writeFileSync(path.join(fixture, 'build'), freshBench
      ? `if (process.argv[2] === 'bench') require('node:fs').writeFileSync(${JSON.stringify(bench)}, 'console.log("fresh");');\n`
      : '');
    const child = runScript(fixture, ['scripts/benchmark.mjs'], { MOON_BIN: process.execPath });
    assert.equal(child.status, 1, child.stderr);
    const report = JSON.parse(fs.readFileSync(path.join(build, 'benchmark-release-summary.json'), 'utf8'));
    assert.equal(report.status, 'failed');
    assert.match(report.error, new RegExp('Build did not produce a nonempty ' + label + ' artifact'));
    assert.deepEqual(report.cases, []);
    assert.equal(fs.existsSync(path.join(fixture, 'stale-executed')), false);
  }
});

test('a benchmark rejects mismatched case names and inconsistent work counts', t => {
  const fixture = makeFixture(t);
  initializeCheckout(fixture);
  fs.writeFileSync(path.join(fixture, 'version'), "console.log('toolchain fixture');\n");
  const output = path.join(fixture, '_build/benchmark-release-summary.json');
  const measured = {
    name: 'selected', inputSize: 2, inputUnit: 'items', iterationsPerSample: 4,
    warmupSamples: 3, expectedPerOperation: 2, checksum: 96,
    samplesMsPerOperation: Array(9).fill(1),
  };
  const cli = `console.log(JSON.stringify(process.argv.includes('--batch')
    ? Array.from({length: 512}, () => ({ok: true, result: 'ok'})) : ['B', 'C']));`;

  for (const [override, problem] of [
    [{ name: 'different' }, /Benchmark case name mismatch for selected/],
    [{ iterationsPerSample: 0 }, /Invalid iteration count for selected/],
    [{ warmupSamples: 2 }, /Invalid warm-up count for selected/],
    [{ checksum: 95 }, /Benchmark checksum mismatch for selected/],
  ]) {
    const bench = `console.log(process.env.MOONJMES_BENCH_CASE
      ? ${JSON.stringify(JSON.stringify({ ...measured, ...override }))} : '["selected"]');`;
    fs.writeFileSync(path.join(fixture, 'build'), `
      const fs = require('node:fs');
      const path = require('node:path');
      const buildingBench = process.argv[2] === 'bench';
      const target = path.join('_build/js/release/build', buildingBench ? 'bench/bench.js' : 'cmd/main/main.js');
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, buildingBench ? ${JSON.stringify(bench)} : ${JSON.stringify(cli)});
    `);
    const child = runScript(fixture, ['scripts/benchmark.mjs'], { MOON_BIN: process.execPath });
    assert.equal(child.status, 1, child.stdout + child.stderr);
    const report = JSON.parse(fs.readFileSync(output, 'utf8'));
    assert.equal(report.status, 'failed');
    assert.match(report.error, problem);
    assert.deepEqual(report.cases, []);
  }
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
