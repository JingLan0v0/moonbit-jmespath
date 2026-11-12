import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const scenarios = [
  ['cloud-inventory', "instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}"],
  ['deployments', "deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}"],
  ['costs', 'sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}'],
];

export function runDemo(cli) {
  function invoke(args, input) {
    const result = spawnSync(process.execPath, [cli, ...args], {
      cwd: root, encoding: 'utf8', timeout: 15_000, maxBuffer: 1024 * 1024, input,
    });
    if (result.error) throw result.error;
    return result;
  }
  function query(args, input) {
    const result = invoke(['--compact', ...args], input);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stderr, '');
    return JSON.parse(result.stdout);
  }

  const ids = query(["instances[?state == 'running'].id", 'examples/cloud-inventory.json']);
  assert.deepEqual(ids, ['i-101', 'i-102', 'i-104']);
  console.log('PASS quick start', JSON.stringify(ids));

  for (const [name, expression] of scenarios) {
    const expected = JSON.parse(fs.readFileSync(path.join(root, 'examples', 'expected', name + '.json'), 'utf8'));
    const actual = query([expression, 'examples/' + name + '.json']);
    assert.deepEqual(actual, expected, name);
    console.log('PASS ' + name, JSON.stringify(actual));
  }

  const requests = [
    { expression: '@', data: 'before' },
    { expression: '!'.repeat(4000) + '@', data: null },
    { expression: '@', data: 'after' },
  ];
  const batch = query(['--batch', '-'], JSON.stringify(requests));
  assert.equal(batch.length, 3);
  assert.deepEqual(batch[0], { ok: true, result: 'before' });
  assert.equal(batch[1].ok, false);
  assert.equal(batch[1].error.code, 'limit_exceeded');
  assert.deepEqual(batch[2], { ok: true, result: 'after' });
  console.log('PASS batch isolation', JSON.stringify(batch.map(item => item.ok ? item.result : item.error.code)));

  const malformed = invoke(['--batch', '-'], '[{"expression":"@","data":1}');
  assert.equal(malformed.status, 2);
  assert.equal(malformed.stdout, '');
  assert.match(malformed.stderr, /invalid_json/);
  console.log('PASS malformed batch JSON (exit 2, empty stdout)');
  return { passed: scenarios.length + 3, scenarios: scenarios.length };
}

if (import.meta.main) {
  const args = process.argv.slice(2);
  assert.ok(args.length === 0 || (args.length === 1 && args[0] === '--release'),
    'Usage: node examples/demo.mjs [--release]');
  const mode = args.includes('--release') ? 'release' : 'debug';
  const moon = process.env.MOON_BIN || 'moon';
  const build = spawnSync(moon, ['build', 'cmd/main', '--target', 'js', ...args], {
    cwd: root, stdio: 'inherit', timeout: 120_000,
  });
  if (build.error) throw build.error;
  assert.equal(build.status, 0, 'CLI build failed');
  runDemo(path.join(root, '_build', 'js', mode, 'build', 'cmd', 'main', 'main.js'));
}
