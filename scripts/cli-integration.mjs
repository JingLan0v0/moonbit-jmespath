import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const cli = process.env.JMES_CLI_PATH || path.join(root, '_build', 'js', 'debug', 'build', 'cmd', 'main', 'main.js');
const version = fs.readFileSync(path.join(root, 'moon.mod'), 'utf8').match(/^version = "([^"]+)"/m)?.[1];
assert.ok(version, 'moon.mod must declare a version');

function invoke(args, input) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: root,
    input,
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024,
    timeout: 15000,
  });
  if (result.error) throw result.error;
  return result;
}

const good = invoke(['--compact', 'items[*].name', '-'], Buffer.from('\uFEFF{"items":[{"name":"月"},{"name":"bit"}]}'));
assert.equal(good.status, 0);
assert.deepEqual(JSON.parse(good.stdout), ['月', 'bit']);
assert.equal(good.stderr, '');

const batch = invoke(['--batch', '--compact', '-'], JSON.stringify([
  { expression: 'name', data: { name: 'Ada' } },
  { expression: 'length()', data: null },
  { expression: 7, data: null },
  { expression: 'name', data: { name: 'Lin' } },
]));
assert.equal(batch.status, 0);
assert.deepEqual(JSON.parse(batch.stdout)[0], { ok: true, result: 'Ada' });
assert.equal(JSON.parse(batch.stdout)[1].error.code, 'invalid_arity');
assert.equal(JSON.parse(batch.stdout)[2].error.code, 'invalid_batch');
assert.deepEqual(JSON.parse(batch.stdout)[3], { ok: true, result: 'Lin' });

// A syntactically short expression can still create extreme parser depth.
// The September acceptance test used this exact 4,001-character shape.
const deeplyNested = `${'!'.repeat(4000)}@`;
const isolatedDepth = invoke(['--batch', '--compact', '-'], JSON.stringify([
  { expression: 'name', data: { name: 'before' } },
  { expression: deeplyNested, data: null },
  { expression: 'name', data: { name: 'after' } },
]));
assert.equal(isolatedDepth.status, 0, isolatedDepth.stderr);
assert.equal(isolatedDepth.stderr, '');
const depthResults = JSON.parse(isolatedDepth.stdout);
assert.equal(depthResults.length, 3);
assert.deepEqual(depthResults[0], { ok: true, result: 'before' });
assert.equal(depthResults[1].ok, false);
assert.equal(depthResults[1].error.code, 'limit_exceeded');
assert.deepEqual(depthResults[2], { ok: true, result: 'after' });

const singleDepth = invoke([deeplyNested, '-'], '{}');
assert.equal(singleDepth.status, 2);
assert.match(singleDepth.stderr, /limit_exceeded/);
assert.equal(singleDepth.stdout, '');

// Grouping invokes the parser recursively without growing the AST. It needs
// the same pre-recursion guard as a long unary prefix.
const deeplyGrouped = `${'('.repeat(300)}@${')'.repeat(300)}`;
const groupedDepth = invoke([deeplyGrouped, '-'], '{}');
assert.equal(groupedDepth.status, 2, groupedDepth.stderr);
assert.match(groupedDepth.stderr, /limit_exceeded/);
assert.equal(groupedDepth.stdout, '');

const malformedBatch = invoke(['--batch', '-'], '{broken');
assert.equal(malformedBatch.status, 2);
assert.match(malformedBatch.stderr, /invalid_json/);

const invalidUtf8 = invoke(['@', '-'], Buffer.from([0xc3, 0x28]));
assert.equal(invalidUtf8.status, 2);
assert.match(invalidUtf8.stderr, /io:/);

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'moonjmes-cli-'));
try {
  const large = path.join(directory, 'large.json');
  const handle = fs.openSync(large, 'w');
  try {
    fs.ftruncateSync(handle, 16 * 1024 * 1024 + 1);
  } finally {
    fs.closeSync(handle);
  }
  const oversized = invoke(['@', large]);
  assert.equal(oversized.status, 2);
  assert.match(oversized.stderr, /input exceeds 16 MiB/);
} finally {
  fs.rmSync(directory, { recursive: true, force: true });
}

const help = invoke(['--version']);
assert.equal(help.status, 0);
assert.equal(help.stdout.trim(), version);
console.log('PASS CLI: stdin, deep-parser batch isolation, invalid input, size limit, and version');
