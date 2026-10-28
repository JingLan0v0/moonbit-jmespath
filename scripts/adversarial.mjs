import assert from 'node:assert/strict';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const root = path.resolve(import.meta.dirname, '..');
const cli = process.env.JMES_CLI_PATH || path.join(root, '_build/js/debug/build/cmd/main/main.js');
let checks = 0;
function invoke(args, input) {
  const result = spawnSync(process.execPath, ['--max-old-space-size=192', cli, ...args], {
    cwd: root, input, encoding: 'utf8', timeout: 15000, maxBuffer: 24 * 1024 * 1024,
  });
  assert.ifError(result.error);
  assert.equal(result.signal, null, 'query must not be killed');
  return result;
}
function isolated(label, expression, data, expectedCode = 'limit_exceeded') {
  const r = invoke(['--batch', '--compact', '-'], JSON.stringify([
    { expression: 'name', data: {name:'before'} },
    { expression, data },
    { expression: 'name', data: {name:'after'} },
  ]));
  assert.equal(r.status, 0, `${label}: ${r.stderr}`);
  assert.equal(r.stderr, '', label);
  const values = JSON.parse(r.stdout);
  assert.equal(values.length, 3, label);
  assert.deepEqual(values[0], {ok:true,result:'before'}, label);
  assert.equal(values[1].ok, false, label);
  assert.equal(values[1].error.code, expectedCode, label);
  assert.deepEqual(values[2], {ok:true,result:'after'}, label);
  checks++;
}

// Historical parser failure and a separate evaluator overflow discovered
// during the October audit. Each used to threaten the entire process.
isolated('September unary input', '!'.repeat(4000)+'@', null);
isolated('nested function execution', 'to_array('.repeat(255)+'@'+')'.repeat(255), null);
for (const [open, close] of [['(',')'], ['{x:','}'], ['[',']'], ['not_null(',')'], ['map(&', ', `[]`)']]) {
  isolated(`parser nesting ${open}`, open.repeat(300)+'@'+close.repeat(300), null);
}
const expansion = Array(30).fill('[@,@]').join('|');
for (const suffix of ['', '|to_string(@)', '|@ == @', '|contains([@], @)']) {
  isolated(`expanded output ${suffix}`, expansion+suffix, 0);
}
isolated('join amplification', 'join(separator, items)', {separator:'x'.repeat(1024*1024),items:Array(32).fill('')});
isolated('non-finite arithmetic', 'sum(@)', [1e308,1e308], 'invalid_value');
let nested = 0;
for (let i=0;i<257;i++) nested=[nested];
isolated('in-memory JSON depth', '@', nested);
isolated('nested JSON literal', '`'+'['.repeat(4000)+'0'+']'.repeat(4000)+'`', null);

const shared = Array(16).fill('[@,@]').join('|');
const largeBatch = invoke(['--batch', '--compact', '-'], JSON.stringify([
  ...Array.from({length:6},()=>({expression:shared,data:0})), {expression:'@',data:'still running'},
]));
assert.equal(largeBatch.status, 0, largeBatch.stderr);
const replies = JSON.parse(largeBatch.stdout);
assert.equal(replies.length, 7);
assert.ok(replies.some(x=>x.ok));
assert.ok(replies.some(x=>!x.ok && x.error.code==='limit_exceeded'));
assert.deepEqual(replies.at(-1), {ok:true,result:'still running'});
checks++;

for (const expression of ['!'.repeat(4000)+'@', 'to_array('.repeat(255)+'@'+')'.repeat(255), expansion]) {
  const r=invoke([expression, '-'], 'null');
  assert.equal(r.status, 2, r.stderr);
  assert.equal(r.stdout, '');
  assert.match(r.stderr, /limit_exceeded/);
  checks++;
}
const invalidTransport = invoke(['--batch','-'], '['.repeat(4000)+'0'+']'.repeat(4000));
assert.equal(invalidTransport.status, 2);
assert.equal(invalidTransport.stdout, '');
assert.match(invalidTransport.stderr, /limit_exceeded/);
checks++;

// Deterministic grammar mutations must be a result or a structured error,
// never a crash. A trailing valid request checks recovery across all items.
let seed=0x4d4f4f4e;
const next=()=>{ seed=(Math.imul(seed,1664525)+1013904223)>>>0; return seed; };
const tokens=['@','!','(',')','[',']','{','}',':',',','.', '|','&&','foo','`1`','&',"'月'"];
const mutations=Array.from({length:256},()=>({expression:Array.from({length:1+next()%50},()=>tokens[next()%tokens.length]).join(''),data:{foo:[1,2]}}));
mutations.push({expression:'@',data:'survived'});
const fuzz=invoke(['--batch','--compact','-'],JSON.stringify(mutations));
assert.equal(fuzz.status,0,fuzz.stderr);
assert.equal(fuzz.stderr,'');
const fuzzReplies=JSON.parse(fuzz.stdout);
assert.equal(fuzzReplies.length,mutations.length);
for(const r of fuzzReplies) {
  assert.equal(typeof r.ok,'boolean');
  if(!r.ok) assert.equal(typeof r.error.code,'string');
}
assert.deepEqual(fuzzReplies.at(-1),{ok:true,result:'survived'});
console.log(`PASS adversarial: ${checks} boundary/isolated-process checks and 256 deterministic grammar mutations`);
