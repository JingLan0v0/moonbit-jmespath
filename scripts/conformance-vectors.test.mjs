import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { DownloadUnavailable, loadVectors, revision } from './lib/conformance-vectors.mjs';

const name = 'basic.json';
const expected = [{ given: '月😀', cases: [{ expression: '@', result: '月😀' }] }];
const bytes = Buffer.from(JSON.stringify(expected) + '\n');
const digest = createHash('sha256').update(bytes).digest('hex');
const altered = Buffer.from(JSON.stringify([{ ...expected[0], cases: [{ expression: '@', result: 'changed' }] }]));

function makeCache(t) {
  const temp = fs.realpathSync(os.tmpdir());
  const cache = fs.mkdtempSync(path.join(temp, 'moonjmes-vectors-test-'));
  t.after(() => {
    assert.equal(path.dirname(fs.realpathSync(cache)), temp);
    assert.ok(path.basename(cache).startsWith('moonjmes-vectors-test-'));
    fs.rmSync(cache, { recursive: true, force: true });
  });
  return { cache, target: path.join(cache, name) };
}

test('verified cached vectors work offline', async t => {
  const { cache, target } = makeCache(t);
  fs.writeFileSync(target, bytes);
  const result = await loadVectors(name, digest, cache, AbortSignal.timeout(5000), () => {
    assert.fail('a verified cache hit should not fetch');
  });
  assert.deepEqual(result, expected);
});

test('bad cache and truncated raw response recover through the pinned contents API', async t => {
  const { cache, target } = makeCache(t);
  fs.writeFileSync(target, altered);
  const urls = [];
  const result = await loadVectors(name, digest, cache, AbortSignal.timeout(5000), async url => {
    urls.push(new URL(url));
    if (urls.length === 1) return new Response(bytes.subarray(0, 10));
    return new Response(JSON.stringify({ encoding: 'base64', content: bytes.toString('base64') }));
  });
  assert.deepEqual(result, expected);
  assert.deepEqual(fs.readFileSync(target), bytes);
  assert.deepEqual(fs.readdirSync(cache), [name]);
  assert.equal(urls.length, 2);
  assert.equal(urls[0].hostname, 'raw.githubusercontent.com');
  assert.ok(urls[0].pathname.includes(revision));
  assert.equal(urls[1].hostname, 'api.github.com');
  assert.equal(urls[1].searchParams.get('ref'), revision);
});

test('bad bytes or an outage cannot replace a cache entry', async t => {
  const { cache, target } = makeCache(t);
  fs.writeFileSync(target, altered);
  await assert.rejects(loadVectors(name, digest, cache, AbortSignal.timeout(5000), async url => {
    if (new URL(url).hostname === 'raw.githubusercontent.com') return new Response(altered);
    return new Response(JSON.stringify({ encoding: 'base64', content: altered.toString('base64') }));
  }), error => !(error instanceof DownloadUnavailable) && /Cannot verify pinned vectors.*SHA-256 mismatch/.test(error.message));
  await assert.rejects(loadVectors(name, digest, cache, AbortSignal.timeout(5000), async () => {
    throw new Error('simulated network outage');
  }), DownloadUnavailable);
  assert.deepEqual(fs.readFileSync(target), altered);
  assert.deepEqual(fs.readdirSync(cache), [name]);
});
