import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import { propertyArtifactPaths } from './lib/property-artifacts.mjs';
import { writeJsonAtomically } from './lib/write-json.mjs';

const root = path.resolve(import.meta.dirname, '..');
const args = process.argv.slice(2);
let mode = 'debug';
let replayPath;
for (let i=0; i<args.length; i++) {
  if (args[i]==='--release' && mode==='debug') mode='release';
  else if (args[i]==='--replay' && !replayPath && args[i+1]) replayPath=path.resolve(args[++i]);
  else throw new Error('Usage: node scripts/equality-properties.mjs [--release] [--replay FILE]');
}
const cli = process.env.JMES_CLI_PATH || path.join(root, `_build/js/${mode}/build/cmd/main/main.js`);
const { report, failure } = propertyArtifactPaths(root, 'equality', mode, replayPath);
if (replayPath) console.log(`Replay report: ${report}`);
fs.rmSync(report, {force:true});
let seed=0x1011e9;
const next=n=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed%n;};
const leaves=[null,false,true,0,1,-1,1.25,1e100,1e-100,'','0','false','é','e\u0301','😀','\u0000','a\nb',[],{}];
const keys=['a','b','__proto__','constructor','toString','','月😀','a\u0000b'];
function value(depth){
  if(depth===0||next(3)===0)return leaves[next(leaves.length)];
  if(next(2))return Array.from({length:next(4)},()=>value(depth-1));
  return Object.fromEntries(Array.from({length:next(4)},()=>[keys[next(keys.length)],value(depth-1)]));
}
function reorder(x){
  if(Array.isArray(x))return x.map(reorder);
  if(x!==null && typeof x==='object')return Object.fromEntries(Object.keys(x).reverse().map(k=>[k,reorder(x[k])]));
  return x;
}
// Canonical JSON is independent from the library's paired tree traversal.
// JSON encoding distinguishes booleans/numbers, and sorting keys ignores object order.
function canonical(x){
  if(Array.isArray(x))return '['+x.map(canonical).join(',')+']';
  if(x!==null && typeof x==='object')return '{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canonical(x[k])).join(',')+'}';
  return JSON.stringify(x);
}
const pairs=[];
for(const a of leaves)for(const b of leaves)pairs.push([a,b]);
for(let i=0;i<1200;i++){
  const a=value(5),b=value(5);
  pairs.push([a,b],[a,reorder(a)],[[a,null],[reorder(a)]]);
}
for(let depth=1;depth<=80;depth++){
  let a=0,b=false;
  for(let i=0;i<depth;i++){a=i%2?[a]:{x:a};b=i%2?[b]:{x:b};}
  pairs.push([a,reorder(a)],[a,b]);
}
pairs.push([{a:null},{}],[{a:1,b:2},{a:1,c:2}],[-0,0],['x'.repeat(20000)+'a','x'.repeat(20000)+'b']);
const cases=[];
for(const [left,right] of pairs){
  const eq=canonical(left)===canonical(right);
  for(const [expression,result] of [['left == right',eq],['right == left',eq],['left != right',!eq],['contains([left], right)',eq],['contains([right], left)',eq]])cases.push({expression,data:{left,right},result});
}

let passed=0;
let active=[];
let batchStart=0;
try {
  const selected = replayPath ? JSON.parse(fs.readFileSync(replayPath, 'utf8')).cases : cases;
  assert.ok(Array.isArray(selected) && selected.length > 0 && selected.length <= cases.length, 'Invalid replay cases');
  for (const c of selected) {
    assert.equal(typeof c.expression, 'string');
    assert.ok(Object.hasOwn(c, 'data'));
    assert.equal(typeof c.result, 'boolean');
  }
  fs.rmSync(failure, { force: true });
  for(let start=0; start<selected.length; start+=250) {
    active=selected.slice(start,start+250);
    batchStart=start;
    const r=spawnSync(process.execPath,['--max-old-space-size=192',cli,'--batch','--compact','-'],{
      cwd:root,input:JSON.stringify(active.map(({expression,data})=>({expression,data}))),
      encoding:'utf8',timeout:15000,maxBuffer:8*1024*1024,
    });
    assert.ifError(r.error);
    assert.equal(r.status,0,(r.stderr||'').slice(0,1024));
    assert.equal(r.stderr,'');
    const got=JSON.parse(r.stdout);
    assert.equal(got.length,active.length);
    const chunk=active;
    for(let i=0;i<chunk.length;i++) {
      // Save one semantic failure, or the entire batch for transport/process failures.
      active=[chunk[i]];
      assert.deepEqual(got[i],{ok:true,result:chunk[i].result},`case ${start+i}`);
      passed++;
    }
  }
} catch(error) {
  const diagnostic = String(error.message).slice(0, 1200);
  console.error(`FAIL equality ${mode}: ${diagnostic}`);
  if (active.length) {
    writeJsonAtomically(failure, {schemaVersion:1,mode,seed:'0x1011e9',batchStart,passed,cases:active});
    console.error(`Replay input: ${failure}`);
  }
  writeJsonAtomically(report, {status: 'failed', mode, passed, failure: active.length ? failure : null,
    replay: replayPath || null, error: diagnostic, recordedAt: new Date().toISOString()});
  process.exit(1);
}
const counts={pairs:replayPath?null:pairs.length,queries:passed};
writeJsonAtomically(report, {status:'passed',mode,...counts,seed:'0x1011e9',replay:replayPath||null,
  cli:path.relative(root,cli),node:process.version,ciCommit:process.env.GITHUB_SHA||null,
  recordedAt:new Date().toISOString()});
console.log(`PASS equality ${mode}: ${passed} queries`);
console.log('EQUALITY_SUMMARY '+JSON.stringify(counts));
