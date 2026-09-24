import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';

const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', ...options });
  if (result.status !== 0) {
    process.stderr.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    throw new Error(`${command} ${args.join(' ')} failed`);
  }
  return result.stdout;
}

run(moon, ['fmt', '--check']);
run(moon, ['check', '--target', 'js']);
run(moon, ['test', '--target', 'js']);
run(moon, ['info', '--target', 'js']);
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

if (process.env.VERIFY_PUBLISH === '1') {
  run(moon, ['publish', '--dry-run']);
  console.log('PASS Mooncakes publish dry-run');
}
console.log('PASS MoonBit checks, tests, examples, interfaces, and build');
