import { evaluators } from './composition-corpus.mjs';

function canonical(x) {
  if (Array.isArray(x)) return '[' + x.map(canonical).join(',') + ']';
  if (x !== null && typeof x === 'object') return '{' + Object.keys(x).sort().map(k => JSON.stringify(k) + ':' + canonical(x[k])).join(',') + '}';
  return JSON.stringify(x);
}
const equalityExpressions = new Set(['left == right', 'right == left', 'left != right',
  'contains([left], right)', 'contains([right], left)']);
export function expectedFor(suite, c, data) {
  if (suite === 'composition') {
    const evaluate = evaluators.get(c.expression);
    return evaluate ? {result: evaluate(data)} : null;
  }
  if (!equalityExpressions.has(c.expression) || data === null || typeof data !== 'object' || Array.isArray(data)) return null;
  const left = Object.hasOwn(data, 'left') ? data.left : null;
  const right = Object.hasOwn(data, 'right') ? data.right : null;
  const equal = canonical(left) === canonical(right);
  return {result: c.expression === 'left != right' ? !equal : equal};
}
