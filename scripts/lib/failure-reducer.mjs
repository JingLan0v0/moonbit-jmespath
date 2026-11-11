import { isDeepStrictEqual } from 'node:util';
import { performance } from 'node:perf_hooks';

const size = x => Buffer.byteLength(JSON.stringify(x));

// Finite, deterministic candidates. No text edits to expressions: deleting
// syntax can turn a semantic failure into an unrelated parser error.
export function* shrinkJson(value) {
  if (value !== null) yield null;
  if (typeof value === 'string') {
    const chars = Array.from(value);
    if (chars.length) yield '';
    for (let width = Math.ceil(chars.length / 2); width >= 1; width = Math.floor(width / 2)) {
      for (let i = 0; i < chars.length; i += width) yield chars.slice(0, i).concat(chars.slice(i + width)).join('');
    }
  } else if (typeof value === 'number' && value !== 0) yield 0;
  else if (value === true) yield false;
  else if (value !== null && typeof value === 'object') {
    const keys = Object.keys(value);
    const list = Array.isArray(value);
    if (keys.length) yield list ? [] : {};
    for (let width = Math.ceil(keys.length / 2); width >= 1; width = Math.floor(width / 2)) {
      for (let i = 0; i < keys.length; i += width) {
        const keep = keys.slice(0, i).concat(keys.slice(i + width));
        yield list ? keep.map(k => value[k]) : Object.fromEntries(keep.map(k => [k, value[k]]));
      }
    }
    for (const key of keys) for (const child of shrinkJson(value[key])) {
      // Object.fromEntries safely preserves __proto__ as an own JSON key.
      const copy = list ? value.slice() : Object.fromEntries(Object.entries(value));
      copy[key] = child;
      yield copy;
    }
  }
}

export function minimizeCases(original, {probe, oracle, maxAttempts = 100, maxMs = 60000,
  reserveMs = 0, now = () => performance.now()}) {
  const start = now();
  let attempts = 0, stopped = null, cases = original;
  const available = () => {
    if (attempts + 2 > maxAttempts) { stopped = 'attempt_limit'; return false; }
    if (now() - start + 2 * reserveMs >= maxMs) { stopped = 'time_limit'; return false; }
    return true;
  };
  const run = candidate => { attempts++; return probe(candidate); };
  const result = (status, signature = null) => ({status, signature, stopReason: stopped || 'fixed_point',
    attempts, elapsedMs: Math.ceil(now() - start), originalCases: original.length,
    remainingCases: cases.length, originalBytes: size(original), remainingBytes: size(cases), cases});
  if (!available()) return result('budget_exhausted');
  const signature = run(cases);
  if (signature === null) return result('not_reproduced');
  if (run(cases) !== signature) return result('unstable', signature);
  function accept(candidate) {
    if (!available()) return false;
    // Preserve category and expression (where available), twice. A timeout,
    // syntax/type error or different mismatch cannot stand in for the original.
    if (run(candidate) !== signature || run(candidate) !== signature) return false;
    cases = candidate;
    return true;
  }
  let changed = true;
  while (changed && !stopped) {
    changed = false;
    let granularity = 2;
    while (cases.length > 1 && !stopped) {
      const width = Math.ceil(cases.length / granularity);
      let reduced = false;
      for (let i = 0; i < cases.length && !stopped; i += width) {
        const candidate = cases.slice(0, i).concat(cases.slice(i + width));
        if (candidate.length && accept(candidate)) { reduced = changed = true; break; }
      }
      if (reduced) granularity = 2;
      else if (granularity >= cases.length) break;
      else granularity = Math.min(cases.length, granularity * 2);
    }
    for (let i = 0; i < cases.length && !stopped; i++) {
      const c = cases[i];
      const expected = oracle(c, c.data);
      if (!expected) continue; // Opaque fixture: keep its data and expectation.
      const saved = Object.hasOwn(c, 'error') ? {error: c.error} : {result: c.result};
      if (!isDeepStrictEqual(expected, saved)) throw new Error('Saved expectation disagrees with independent oracle');
      for (const data of shrinkJson(c.data)) {
        if (!available()) break;
        const updated = oracle(c, data);
        if (!updated) continue;
        const {result: oldResult, error: oldError, ...request} = c;
        const candidate = cases.slice();
        candidate[i] = {...request, data, ...updated};
        if (size(candidate) < size(cases) && accept(candidate)) { changed = true; break; }
      }
    }
  }
  return result(size(cases) < size(original) ? 'reduced' : 'unchanged', signature);
}

export function responseSignature(cases, responses) {
  if (!Array.isArray(responses) || responses.length !== cases.length) return 'protocol:batch-shape';
  for (let i = 0; i < cases.length; i++) {
    const c = cases[i], r = responses[i];
    if (!r || typeof r !== 'object' || typeof r.ok !== 'boolean' ||
        (r.ok ? !Object.hasOwn(r, 'result') : typeof r.error?.code !== 'string')) return 'protocol:item-shape';
    const suffix = ':' + c.expression;
    if (Object.hasOwn(c, 'error')) {
      if (r.ok) return 'missing-error:' + c.error + suffix;
      if (r.error.code !== c.error) return 'wrong-error:' + c.error + ':' + r.error.code + suffix;
    } else if (!r.ok) return 'unexpected-error:' + r.error.code + suffix;
    else if (!isDeepStrictEqual(r, {ok: true, result: c.result})) return 'value-mismatch' + suffix;
  }
  return null;
}
