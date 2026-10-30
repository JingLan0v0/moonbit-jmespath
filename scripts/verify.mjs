import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';

const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 120000, ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    process.stderr.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    throw new Error(`${command} ${args.join(' ')} failed`);
  }
  return result.stdout;
}

run(moon, ['fmt', '--check']);
run(moon, ['check', '--target', 'js', '--deny-warn']);
const unitTests = run(moon, ['test', '--target', 'js', '--deny-warn']);
process.stdout.write(unitTests);
run(moon, ['info', '--target', 'js']);
for (const mode of [[], ['--release']]) {
  const output = run(moon, ['run', 'examples/library', '--target', 'js', ...mode]);
  if (output.trim().replaceAll('\r', '') !== '["Ada"]\n[]\nerror: invalid_type') {
    throw new Error(`Public API example mismatch: ${output}`);
  }
}
console.log('PASS public API example: compile reuse, limits, serialization and error handling');
run(moon, ['build', 'cmd/main', '--target', 'js']);

const cli = path.join(root, '_build', 'js', 'debug', 'build', 'cmd', 'main', 'main.js');
const scenarios = [
  ['cloud-inventory', "instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}"],
  ['deployments', "deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}"],
  ['costs', 'sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}'],
];
for (const [name, expression] of scenarios) {
  const actual = JSON.parse(run(process.execPath, [cli, '--compact', expression, `examples/${name}.json`]));
  const expected = JSON.parse(fs.readFileSync(path.join(root, 'examples', 'expected', `${name}.json`), 'utf8'));
  if (!isDeepStrictEqual(actual, expected)) throw new Error(`${name} output mismatch`);
  console.log(`PASS scenario: ${name}`);
}

process.stdout.write(run(process.execPath, ['scripts/cli-integration.mjs']));
process.stdout.write(run(process.execPath, ['scripts/adversarial.mjs']));

run(moon, ['build', 'cmd/main', '--target', 'js', '--release']);
const releaseCli = path.join(root, '_build', 'js', 'release', 'build', 'cmd', 'main', 'main.js');
process.stdout.write(run(process.execPath, ['scripts/cli-integration.mjs'], {
  env: { ...process.env, JMES_CLI_PATH: releaseCli },
}));
process.stdout.write(run(process.execPath, ['scripts/adversarial.mjs'], {
  env: { ...process.env, JMES_CLI_PATH: releaseCli },
}));

if (process.env.VERIFY_PUBLISH === '1') {
  const publish = spawnSync(moon, ['publish', '--dry-run'], { cwd: root, encoding: 'utf8' });
  const detail = (publish.stdout || '') + (publish.stderr || '');
  // Moon 0.1.20260920 exits non-zero after a server-confirmed 202 dry-run.
  if (publish.status !== 0 && !detail.includes('Dry run completed successfully')) {
    process.stderr.write(detail);
    throw new Error('Mooncakes publish dry-run failed');
  }
  console.log('PASS Mooncakes publish dry-run');
}
console.log('PASS MoonBit checks, tests, examples, interfaces, and debug/release builds');
fs.writeFileSync(path.join(root, '_build', 'verification-summary.json'), JSON.stringify({
  status: 'passed', ciCommit: process.env.GITHUB_SHA || null,
  node: process.version, recordedAt: new Date().toISOString(),
  unitTests: unitTests.trim(), scenarios: scenarios.map(x=>x[0]),
  cliModes: ['debug', 'release'], adversarialChecksPerMode: 27, grammarMutationsPerMode: 256,
  publicApiExampleModes: ['debug', 'release'],
}, null, 2)+'\n');
