import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';

test('a source-check failure removes stale suite evidence', t => {
  const temp = fs.realpathSync(os.tmpdir());
  const fixture = fs.mkdtempSync(path.join(temp, 'moonjmes-report-test-'));
  t.after(() => {
    assert.equal(path.dirname(fs.realpathSync(fixture)), temp);
    assert.ok(path.basename(fixture).startsWith('moonjmes-report-test-'));
    fs.rmSync(fixture, { recursive: true, force: true });
  });

  const project = path.resolve(import.meta.dirname, '..');
  for (const file of ['scripts/verify.mjs', 'examples/demo.mjs']) {
    const destination = path.join(fixture, file);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(project, file), destination);
  }
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

  const child = spawnSync(process.execPath, [path.join(fixture, 'scripts', 'verify.mjs')], {
    cwd: fixture, encoding: 'utf8', timeout: 15_000,
    env: { ...process.env, GIT_DIR: path.join(fixture, 'missing-git-directory') },
  });
  if (child.error) throw child.error;
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
