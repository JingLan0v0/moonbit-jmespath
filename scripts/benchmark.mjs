import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';

const args = process.argv.slice(2);
if (args.length && (args.length !== 1 || args[0] !== '--debug')) {
  throw new Error('Usage: node scripts/benchmark.mjs [--debug]');
}
const mode = args.includes('--debug') ? 'debug' : 'release';
const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
const build = path.join(root, '_build');
const output = path.join(build, `benchmark-${mode}-summary.json`);
const report = {
  schemaVersion: 1,
  status: 'running',
  target: 'js',
  mode,
  startedAt: new Date().toISOString(),
  environment: {
    node: process.version,
    platform: process.platform,
    osRelease: os.release(),
    arch: process.arch,
    cpu: os.cpus()[0]?.model ?? null,
    logicalCpus: os.cpus().length,
    totalMemoryBytes: os.totalmem(),
    nodeOldSpaceMiB: 256,
  },
  cases: [],
};

function run(command, args, options = {}) {
  const start = performance.now();
  const child = spawnSync(command, args, {
    cwd: root, encoding: 'utf8', timeout: 120_000, maxBuffer: 4 * 1024 * 1024, ...options,
  });
  const wallMs = performance.now() - start;
  if (child.error) throw child.error;
  if (child.status !== 0) {
    throw new Error(`${command} ${args.join(' ')}: ${child.stderr || child.stdout || child.signal}`);
  }
  return { stdout: child.stdout, wallMs };
}

function summarize(samples) {
  assert.equal(samples.length, 9);
  assert.ok(samples.every(value => Number.isFinite(value) && value >= 0), 'Invalid timing sample');
  const sorted = [...samples].sort((a, b) => a - b);
  return { min: sorted[0], median: sorted[4], max: sorted[8] };
}

function record(name, measurement, details) {
  const statsMs = summarize(details.samplesMsPerOperation);
  report.cases.push({ name, measurement, ...details, statsMs });
  console.log(`${name}: median ${statsMs.median.toFixed(3)} ms [${statsMs.min.toFixed(3)}, ${statsMs.max.toFixed(3)}]`);
}

function processCase(name, args, input, expected, requests = null) {
  const samples = [];
  for (let i = 0; i < 11; i++) {
    const { stdout, wallMs } = run(process.execPath, ['--max-old-space-size=256', ...args], { input });
    if (expected === undefined) assert.equal(stdout, '');
    else assert.deepEqual(JSON.parse(stdout), expected);
    if (i >= 2) samples.push(wallMs);
  }
  record(name, 'process wall time including startup', {
    inputBytes: Buffer.byteLength(input),
    requests,
    iterationsPerSample: 1,
    warmupSamples: 2,
    samplesMsPerOperation: samples,
    peakRssKiB: null,
  });
}

fs.mkdirSync(build, { recursive: true });
fs.rmSync(output, { force: true });
try {
  report.source = {
    sha: run('git', ['rev-parse', 'HEAD']).stdout.trim(),
    dirty: run('git', ['status', '--porcelain']).stdout.trim() !== '',
  };
  report.environment.toolchain = run(moon, ['version', '--all']).stdout.trim();
  const flags = mode === 'release' ? ['--release'] : [];
  const benchBuild = run(moon, ['build', 'bench', '--target', 'js', ...flags]);
  const cliBuild = run(moon, ['build', 'cmd/main', '--target', 'js', ...flags]);
  report.buildMs = { libraryHarness: benchBuild.wallMs, cli: cliBuild.wallMs };
  const artifactDir = path.join(build, 'js', mode, 'build');
  const bench = path.join(artifactDir, 'bench', 'bench.js');
  const cli = path.join(artifactDir, 'cmd', 'main', 'main.js');
  function runCase(name) {
    return run(process.execPath, ['--max-old-space-size=256', bench], {
      env: { ...process.env, MOONJMES_BENCH_CASE: name },
    });
  }
  const names = JSON.parse(runCase('').stdout);
  assert.ok(Array.isArray(names) && names.length > 0 && new Set(names).size === names.length);
  for (const name of names) {
    const { stdout, wallMs } = runCase(name);
    record(name, 'in-process operation', { ...JSON.parse(stdout), processWallMs: wallMs });
  }
  processCase('node-startup', ['-e', ''], '', undefined);
  const items = [{ price: 8, name: 'A' }, { price: 12, name: 'B' }, { price: 10, name: 'C' }];
  processCase('cli-filter', [cli, '--compact', 'items[?price >= `10`].name', '-'],
    JSON.stringify({ items }), ['B', 'C']);
  const requests = Array.from({ length: 512 }, () => ({
    expression: 'not_null(missing0000, value)', data: { value: 'ok' },
  }));
  processCase('cli-batch', [cli, '--batch', '--compact', '-'],
    JSON.stringify(requests), requests.map(() => ({ ok: true, result: 'ok' })), requests.length);
  report.status = 'passed';
} catch (error) {
  report.status = 'failed';
  report.error = error.message;
  process.exitCode = 1;
  console.error(report.error);
} finally {
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
  console.log(`Benchmark ${report.status}: ${output}`);
}
