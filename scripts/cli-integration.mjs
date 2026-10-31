import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';

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

// Exercise merge-run boundaries and stable ties against Node's independent sort.
for (const size of [0,1,2,3,31,32,33,257]) {
  const values = Array.from({length:size},(_,i)=>(i*73+19)%41-20);
  const records = values.map((key,id)=>({key,id}));
  const r = invoke(['--batch','--compact','-'], JSON.stringify([
    {expression:'sort(@)',data:values},
    {expression:'sort_by(@, &key)[*].id',data:records},
  ]));
  assert.equal(r.status, 0, r.stderr);
  assert.deepEqual(JSON.parse(r.stdout), [
    {ok:true,result:[...values].sort((a,b)=>a-b)},
    {ok:true,result:[...records].sort((a,b)=>a.key-b.key).map(x=>x.id)},
  ]);
}

// Explicit specification examples spanning the UTF-16 surrogate boundary.
const orderedUnicode = ['', 'A', 'a', 'e\u0301', 'é', '月', '\ue000', '\uffff', '\u{10000}', '😀', '😀x', '\u{10ffff}'];
const unorderedUnicode = [...orderedUnicode].reverse();
const records = unorderedUnicode.map((key,id)=>({key,id}));
const semanticCases = [
  ['sort(@)', unorderedUnicode, orderedUnicode],
  ['min(@)', unorderedUnicode, ''],
  ['max(@)', unorderedUnicode, '\u{10ffff}'],
  ['sort_by(@, &key)[*].key', records, orderedUnicode],
  ['min_by(@, &key).key', records, ''],
  ['max_by(@, &key).key', records, '\u{10ffff}'],
  ['length(@)', 'a😀月', 3], ['reverse(@)', 'a😀月', '月😀a'],
  ['sort(@)', [1e308, -1e308, 0, 1e-308, -1e-308], [-1e308, -1e-308, 0, 1e-308, 1e308]],
];
const semanticRun = invoke(['--batch', '--compact', '-'], JSON.stringify(semanticCases.map(([expression,data])=>({expression,data}))));
assert.equal(semanticRun.status, 0, semanticRun.stderr);
assert.equal(semanticRun.stderr, '');
assert.deepEqual(JSON.parse(semanticRun.stdout), semanticCases.map(([, ,result])=>({ok:true,result})));

// Nulls have different behavior in multi-select, subexpressions and projections.
const nullCases = [
  ['[foo,bar]', null, null], ['{a:foo}', null, null],
  ['[unknown_function()]', null, null], ['[foo,bar]', {}, [null,null]],
  ['missing.to_array(@)', {}, [null]],
  ["missing.not_null(@, 'fallback')", {}, 'fallback'],
  ['missing.type(@)', {}, 'null'], ['missing.[foo]', {}, null],
  ['[*].[x]', [null,{x:1},{}], [[1],[null]]],
  ['map(&[x], @)', [null,{x:1},{}], [null,[1],[null]]],
];
const nullRun = invoke(['--batch', '--compact', '-'], JSON.stringify(nullCases.map(([expression,data])=>({expression,data}))));
assert.equal(nullRun.status, 0, nullRun.stderr);
assert.equal(nullRun.stderr, '');
assert.deepEqual(JSON.parse(nullRun.stdout), nullCases.map(([, ,result])=>({ok:true,result})));
const nullError = invoke(['missing.length(@)', '-'], '{}');
assert.equal(nullError.status, 2);
assert.equal(nullError.stdout, '');
assert.match(nullError.stderr, /invalid_type/);
const documentedBatch = invoke(['--batch', '--compact', 'examples/batch.json']);
assert.equal(documentedBatch.status, 0, documentedBatch.stderr);
const documentedReplies = JSON.parse(documentedBatch.stdout);
assert.equal(documentedReplies.length, 3);
assert.deepEqual(documentedReplies[0], {ok:true,result:'Ada'});
assert.equal(documentedReplies[1].error.code, 'invalid_arity');
assert.deepEqual(documentedReplies[2], {ok:true,result:'fallback'});

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
const closedPipe = await new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [cli, '--compact', '@', '-'], {cwd:root});
  let stderr = '';
  const timer = setTimeout(() => { child.kill(); reject(new Error('closed-pipe test timed out')); }, 15000);
  child.on('error', error => { clearTimeout(timer); reject(error); });
  child.stderr.on('data', chunk => { stderr += chunk.toString(); });
  child.stdin.on('error', error => { clearTimeout(timer); child.kill(); reject(error); });
  child.on('close', (code, signal) => { clearTimeout(timer); resolve({code, signal, stderr}); });
  child.stdout.destroy();
  child.stdin.end(JSON.stringify('x'.repeat(512 * 1024)));
});
assert.equal(closedPipe.signal, null);
assert.equal(closedPipe.code, 2, closedPipe.stderr);
assert.match(closedPipe.stderr, /^moon-jmes: io: stdout [A-Z0-9_]+\n$/);
const hostileOption = invoke(['--bad\nFORGED\r\u001b[2J\u202e']);
assert.equal(hostileOption.status, 2);
assert.equal(hostileOption.stdout, '');
assert.match(hostileOption.stderr, /\\u000aFORGED\\u000d\\u001b\[2J\\u202e/);
assert.equal(hostileOption.stderr.split('\n').length, 2);
assert.doesNotMatch(hostileOption.stderr, /[\u0000-\u0009\u000b-\u001f\u007f-\u009f\u2028-\u202e\u2066-\u2069]/);
// A read-only file descriptor deterministically fails output on both CI OSes.
const readonly = fs.openSync(path.join(root, 'moon.mod'), 'r');
try {
  for (const [args, stdio, diagnostic] of [
    [['--version'], ['ignore', readonly, 'pipe'], true],
    [['--bad'], ['ignore', 'pipe', readonly], false],
    [['--version'], ['ignore', readonly, readonly], false],
  ]) {
    const failed = spawnSync(process.execPath, [cli, ...args], {
      cwd:root, stdio, encoding:'utf8', timeout:15000,
    });
    assert.ifError(failed.error);
    assert.equal(failed.signal, null);
    assert.equal(failed.status, 2, failed.stderr);
    if (diagnostic) {
      assert.match(failed.stderr, /^moon-jmes: io: stdout [A-Z0-9_]+\n$/);
      assert.doesNotMatch(failed.stderr, /Unhandled|node:events|at .*\.js/);
    }
  }
} finally {
  fs.closeSync(readonly);
}
console.log('PASS CLI: stdin, deep-parser batch isolation, invalid input, size limit, and version');
