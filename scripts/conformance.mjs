import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';

const revision = '53abcc37901891cf4308fcd910eab287416c4609';
const files = [
  'basic.json', 'boolean.json', 'current.json', 'escape.json',
  'filters.json', 'functions.json', 'identifiers.json', 'indices.json',
  'literal.json', 'multiselect.json', 'pipe.json', 'slice.json',
  'syntax.json', 'unicode.json', 'wildcard.json',
];
const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
const release = process.argv.includes('--release');
const build = spawnSync(moon, ['build', 'cmd/main', '--target', 'js', ...(release ? ['--release'] : [])], {
  cwd: root, encoding: 'utf8',
});
if (build.status !== 0) {
  process.stderr.write(build.stderr || build.stdout);
  process.exit(2);
}
const cli = path.join(root, '_build', 'js', release ? 'release' : 'debug', 'build', 'cmd', 'main', 'main.js');
const cache = path.join(os.tmpdir(), `jmespath-test-${revision}`);
fs.mkdirSync(cache, { recursive: true });

for (const name of files) {
  const target = path.join(cache, name);
  if (!fs.existsSync(target)) {
    const url = `https://raw.githubusercontent.com/jmespath/jmespath.test/${revision}/tests/${name}`;
    let text;
    try {
      const response = await fetch(url, {signal: AbortSignal.timeout(15000)});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      text = await response.text();
    } catch (rawError) {
      // Same upstream file and exact revision, through GitHub's documented API.
      const api = `https://api.github.com/repos/jmespath/jmespath.test/contents/tests/${name}?ref=${revision}`;
      const response = await fetch(api, {signal: AbortSignal.timeout(15000)});
      if (!response.ok) throw new Error(`download failed (${response.status}): ${api}`, {cause:rawError});
      const file = await response.json();
      if(file.encoding!=='base64' || typeof file.content!=='string') throw new Error(`invalid upstream content: ${name}`);
      text = Buffer.from(file.content, 'base64').toString('utf8');
    }
    if (!Array.isArray(JSON.parse(text))) throw new Error(`invalid test data: ${name}`);
    fs.writeFileSync(target+'.tmp', text);
    fs.renameSync(target+'.tmp', target);
  }
}

const cases = [];
const requests = [];
for (const name of files) {
  for (const group of JSON.parse(fs.readFileSync(path.join(cache, name), 'utf8'))) {
    for (const test of group.cases) {
      cases.push({ file: name, ...test });
      requests.push({ expression: test.expression, data: group.given });
    }
  }
}

const run = spawnSync(process.execPath, [cli, '--batch', '--compact', '-'], {
  input: JSON.stringify(requests), encoding: 'utf8', maxBuffer: 32 * 1024 * 1024,
  timeout: 60000,
});
if (run.error) throw run.error;
if (run.status !== 0) {
  process.stderr.write(run.stderr || run.stdout);
  process.exit(2);
}
const responses = JSON.parse(run.stdout);
if (!Array.isArray(responses) || responses.length !== cases.length) throw new Error('missing or extra compliance responses');
const failures = [];
for (let i = 0; i < cases.length; i++) {
  const test = cases[i];
  const response = responses[i];
  const ok = 'error' in test
    ? response.ok === false && response.error?.code === test.error.replaceAll('-', '_')
    : response.ok === true && isDeepStrictEqual(response.result, test.result);
  if (!ok) failures.push({ file: test.file, expression: test.expression, expected: test.error ?? test.result, response });
}

console.log(`JMESPath compliance: ${cases.length - failures.length}/${cases.length}`);
console.log(`Suite revision: ${revision}`);
console.log(`Build mode: ${release ? 'release' : 'debug'}`);
fs.writeFileSync(path.join(root, '_build', `conformance-${release ? 'release' : 'debug'}-summary.json`), JSON.stringify({
  revision, mode: release ? 'release' : 'debug', total: cases.length,
  passed: cases.length-failures.length, failures,
  ciCommit: process.env.GITHUB_SHA || null, recordedAt: new Date().toISOString(),
},null,2)+'\n');
if (failures.length) {
  console.error(JSON.stringify(failures.slice(0, 20), null, 2));
  process.exit(1);
}
