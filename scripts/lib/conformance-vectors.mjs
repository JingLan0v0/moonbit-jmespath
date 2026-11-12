import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';

export const revision = '53abcc37901891cf4308fcd910eab287416c4609';

// SHA-256 of the unmodified files at the pinned upstream revision.
export const pinnedFiles = {
  'basic.json': 'e02b094b3de1707a851244e532ced95f128ec4fb815105773d46d9f9cc2ff0b1',
  'boolean.json': '46066f0fc2b11ddf2595431d7a3b2f2e78951d955ea576a5bca417ddd67603c8',
  'current.json': '77bf364258f5fefa80a74a185ff8f926a7d68f911e36bb0b6b4bf2f204c536d0',
  'escape.json': '55b09670b206d2fa89779dd02b5d187812855b109b697224e51f5ed0dd8289d6',
  'filters.json': 'f3f8335a45a2eec42cc1990f8fdd141f6042239ee7d21257dcdc9a45ba2d79dc',
  'functions.json': 'ddd72be78d426c6f8e3f3e3ef91cf4757280f3e335706f212401a93882ba46f4',
  'identifiers.json': '370731bfb3fa63bba058935bdae43c5fb5db7a71200c49a7ed7387f23201beaf',
  'indices.json': '0d534b29a2dbe0446325276e2ac24122b3a497e28bf49db32fc04651ff46e0f8',
  'literal.json': '25c7454b9f10990f840b815ae5a9c6de8164046eaa1d405050b3cd619ff47669',
  'multiselect.json': '96b4d0f9be202c207d1689942592675462992dba0c6bcdffefcfb04bc32ef1c9',
  'pipe.json': '5cc702a91520055bb0c22307d4e3ab496a4d01dca6220eef3533eacb335c1823',
  'slice.json': '423a616e9f54fdf616e7d2e41a2567e46117fb7cdbce8c4ef86d22512ad2dd19',
  'syntax.json': '501712ded6da60cc18ed99316cbac1c66b389f9d285f2f96bef4afff4a43e43b',
  'unicode.json': '5a341b0faca2c9151d7ca0cd281c679cd37a399acda700198401454add0d8f86',
  'wildcard.json': '32b2a981b3e380a65a73d4145d4093c684133e697c694ac65e1621b87a852cd7',
};

export class DownloadUnavailable extends Error {}
class InvalidVectors extends Error {}

function decodeContentsApi(bytes) {
  try {
    const file = JSON.parse(bytes.toString('utf8'));
    if (file?.encoding === 'base64' && typeof file.content === 'string') {
      return Buffer.from(file.content, 'base64');
    }
  } catch (error) {
    throw new InvalidVectors('Invalid contents API JSON', { cause: error });
  }
  throw new InvalidVectors('Invalid contents API encoding or content');
}

export async function loadVectors(name, digest, cache, downloadBudget, fetchFile = fetch) {
  const target = path.join(cache, name);
  const matches = bytes => createHash('sha256').update(bytes).digest('hex') === digest;
  let cached;
  try {
    cached = fs.readFileSync(target);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  if (cached && matches(cached)) return JSON.parse(cached.toString('utf8'));

  async function download(url, decode) {
    const signal = AbortSignal.any([downloadBudget, AbortSignal.timeout(12000)]);
    const response = await fetchFile(url, { signal });
    if (!response.ok) throw new Error('HTTP ' + response.status);
    const body = Buffer.from(await response.arrayBuffer());
    const bytes = decode ? decode(body) : body;
    if (!matches(bytes)) throw new InvalidVectors('SHA-256 mismatch');
    return bytes;
  }

  const raw = `https://raw.githubusercontent.com/jmespath/jmespath.test/${revision}/tests/${name}`;
  let bytes;
  try {
    bytes = await download(raw);
  } catch (rawError) {
    const api = `https://api.github.com/repos/jmespath/jmespath.test/contents/tests/${name}?ref=${revision}`;
    try {
      bytes = await download(api, decodeContentsApi);
    } catch (apiError) {
      const detail = `${name} (${cached ? 'invalid cache' : 'cache miss'}): raw ${rawError.message}; API ${apiError.message}`;
      if (rawError instanceof InvalidVectors || apiError instanceof InvalidVectors) {
        throw new InvalidVectors('Cannot verify pinned vectors ' + detail);
      }
      throw new DownloadUnavailable('Cannot download pinned vectors ' + detail);
    }
  }

  const vectors = JSON.parse(bytes.toString('utf8'));
  const temporary = `${target}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, bytes);
    fs.renameSync(temporary, target);
  } finally {
    fs.rmSync(temporary, { force: true });
  }
  return vectors;
}
