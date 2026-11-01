import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const cli = process.env.JMES_CLI_PATH || path.join(root, '_build/js/debug/build/cmd/main/main.js');
function invoke(args, input) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: root, input, encoding: 'utf8', timeout: 15000, maxBuffer: 24 * 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stderr, '');
  return JSON.parse(result.stdout);
}

// Compare parsed CLI output with independently built Node objects. Special keys
// must be data properties, not object-prototype setters.
const keys = [
  '__proto__', 'constructor', 'prototype', 'toString', 'hasOwnProperty', '',
  'a.b', '[?x]', 'quote"', 'slash\\', 'line\n', 'nul\0', '月😀', '\u202e', '0', '01',
];
const values = ['"\\\b\f\n\r\t\0', '月😀\u2028\u2029', null, false, 0];
const data = Object.fromEntries(keys.map((key, i) => [key, {
  value: values[i % values.length], index: i,
}]));
const cases = [
  ['@', data, data],
  ...keys.map(key => [JSON.stringify(key), data, data[key]]),
  ['merge(@, `{"__proto__":7,"constructor":8}`)', data,
    { ...data, ['__proto__']: 7, constructor: 8 }],
  ['{"x": `1`, "x": `2`}', {}, { x: 2 }],
];
for (let i = 0; i < 256; i++) {
  const key = String.fromCharCode(i) + '月😀';
  const object = Object.fromEntries([[key, values[i % values.length]]]);
  cases.push(['@', object, object], [JSON.stringify(key), object, object[key]]);
}
for (const compact of [true, false]) {
  const format = compact ? ['--compact'] : [];
  const results = invoke(['--batch', ...format, '-'],
    JSON.stringify(cases.map(([expression, data]) => ({ expression, data }))));
  assert.equal(results.length, cases.length);
  results.forEach((result, i) => {
    assert.deepEqual(result, { ok: true, result: cases[i][2] }, cases[i][0]);
  });
  const duplicate = invoke([...format, '@', '-'],
    '{"x":1,"x":2,"__proto__":{"a":1},"__proto__":{"a":2}}');
  assert.deepEqual(duplicate, JSON.parse('{"x":2,"__proto__":{"a":2}}'));
  console.log(`PASS JSON roundtrip ${compact ? 'compact' : 'pretty'}: ${cases.length} key/escape cases and duplicate JSON key case passed`);
}
