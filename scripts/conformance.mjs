import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';

import { DownloadUnavailable, loadVectors, pinnedFiles, revision } from './lib/conformance-vectors.mjs';

const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
const args = process.argv.slice(2);
const release = args.includes('--release');
const mode = release ? 'release' : 'debug';
const output = path.join(root, '_build', `conformance-${mode}-summary.json`);
const cache = path.resolve(process.env.JMES_CONFORMANCE_CACHE ?? path.join(os.tmpdir(), `jmespath-test-${revision}`));
const report = { status: 'running', revision, mode, total: null, passed: null, failures: [],
  ciCommit: process.env.GITHUB_SHA || null, startedAt: new Date().toISOString() };
const networkBlockedExit = 3;

async function verify() {
  let cli = path.join(root, '_build', 'js', mode, 'build', 'cmd', 'main', 'main.js');
  const options = args.filter(arg => arg !== '--release');
  if (options.length === 2 && options[0] === '--cli') {
    cli = path.resolve(options[1]);
  } else if (options.length === 0) {
    const build = spawnSync(moon, ['build', 'cmd/main', '--target', 'js', ...(release ? ['--release'] : [])], {
      cwd: root, encoding: 'utf8', timeout: 120000,
    });
    if (build.error) throw build.error;
    if (build.status !== 0) throw new Error(`JS build failed: ${build.stderr || build.stdout}`);
  } else {
    throw new Error('Usage: node scripts/conformance.mjs [--release] [--cli FILE]');
  }
  if (!fs.existsSync(cli) || !fs.statSync(cli).isFile()) throw new Error(`Missing CLI artifact: ${cli}`);
  report.cli = path.relative(root, cli);
  fs.mkdirSync(cache, { recursive: true });
  const cases = [];
  const requests = [];
  const downloadBudget = AbortSignal.timeout(45000);
  for (const [name, digest] of Object.entries(pinnedFiles)) {
    for (const group of await loadVectors(name, digest, cache, downloadBudget)) {
      for (const test of group.cases) {
        cases.push({ file: name, ...test });
        requests.push({ expression: test.expression, data: group.given });
      }
    }
  }
  report.total = cases.length;
  if (cases.length !== 892) throw new Error(`Expected 892 pinned cases, found ${cases.length}`);
  const run = spawnSync(process.execPath, [cli, '--batch', '--compact', '-'], {
    cwd: root, input: JSON.stringify(requests), encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, timeout: 60000,
  });
  if (run.error) throw run.error;
  if (run.status !== 0) throw new Error(`CLI failed: ${run.stderr || run.stdout}`);
  const responses = JSON.parse(run.stdout);
  if (!Array.isArray(responses) || responses.length !== cases.length) throw new Error('Missing or extra compliance responses');
  for (let i = 0; i < cases.length; i++) {
    const test = cases[i];
    const response = responses[i];
    const ok = 'error' in test
      ? response?.ok === false && response.error?.code === test.error.replaceAll('-', '_')
      : response?.ok === true && isDeepStrictEqual(response.result, test.result);
    if (!ok) report.failures.push({ file: test.file, expression: test.expression, expected: test.error ?? test.result, response });
  }
  report.passed = cases.length - report.failures.length;
  console.log(`JMESPath compliance: ${report.passed}/${report.total}`);
  console.log(`Suite revision: ${revision}`);
  console.log(`Build mode: ${mode}`);
  if (report.failures.length) {
    console.error(JSON.stringify(report.failures.slice(0, 20), null, 2));
    throw new Error(`${report.failures.length} official cases failed`);
  }
}

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.rmSync(output, { force: true });
try {
  await verify();
  report.status = 'passed';
} catch (error) {
  const blocked = error instanceof DownloadUnavailable;
  report.status = blocked ? 'network_blocked' : 'failed';
  report.error = error.message.slice(0, 1600);
  console.error(report.error);
  process.exitCode = blocked ? networkBlockedExit : 1;
} finally {
  report.finishedAt = new Date().toISOString();
  fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
}
