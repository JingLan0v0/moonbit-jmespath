import { createHash } from 'node:crypto';

export const initialSeed = 0x20261111;
let seed = initialSeed;
const next = n => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return Math.floor(seed / 0x100000000 * n); };
const type = x => x === null ? 'null' : Array.isArray(x) ? 'array' : typeof x;
const field = (x, key) => type(x) === 'object' && Object.hasOwn(x, key) ? x[key] : null;
const truth = x => !(x === null || x === false || x === '' ||
  (Array.isArray(x) && x.length === 0) || (type(x) === 'object' && Object.keys(x).length === 0));
const array = x => Array.isArray(x) ? x : [x];
const project = (x, fn) => Array.isArray(x) ? x.map(fn).filter(v => v !== null) : null;
const node = (expression, evaluate) => ({ expression, evaluate });
const atoms = [node('@', x => x), ...['a', 'b', 'items'].map(k => node(k, x => field(x, k))),
  ...[null, false, true, 0, [], {}, [1, null, false], '😀'].map(x => node('`' + JSON.stringify(x) + '`', () => x))];

// Construct text and expected-value closures together. There is no expression
// parser here and no imported reference evaluator. This is a controlled grammar,
// not a claim to generate every legal JMESPath expression. Parentheses explicitly
// close a child's projection before its parent's operation.
const categories = ['group', 'not', 'type', 'to_array', 'not_null', 'or', 'and',
  'pipe', 'projection', 'index', 'filter', 'map', 'flatten', 'reverse_length'];
function generate(depth, choice = next(categories.length)) {
  if (depth === 0) return atoms[next(atoms.length)];
  const a = generate(depth - 1), s = '(' + a.expression + ')', ev = a.evaluate;
  switch (categories[choice]) {
    case 'group': return node(s, ev);
    case 'not': return node('!' + s, x => !truth(ev(x)));
    case 'type': return node(`type(${s})`, x => type(ev(x)));
    case 'to_array': return node(`to_array(${s})`, x => array(ev(x)));
    case 'not_null': return node(`not_null(${s}, b, \`0\`)`, x => ev(x) ?? field(x, 'b') ?? 0);
    case 'or': return node(`${s} || b`, x => { const v = ev(x); return truth(v) ? v : field(x, 'b'); });
    case 'and': return node(`${s} && b`, x => { const v = ev(x); return truth(v) ? field(x, 'b') : v; });
    case 'pipe': {
      const b = generate(depth - 1);
      return node(`${s} | (${b.expression})`, x => b.evaluate(ev(x)));
    }
    case 'projection': return node(`${s}[*].a`, x => project(ev(x), v => field(v, 'a')));
    case 'index': return node(`${s}[-1]`, x => { const v = ev(x); return Array.isArray(v) ? v.at(-1) ?? null : null; });
    case 'filter': return node(`${s}[?@].a`, x => { const v = ev(x); return Array.isArray(v) ? project(v.filter(truth), y => field(y, 'a')) : null; });
    case 'map': {
      const b = generate(depth - 1);
      return node(`map(&(${b.expression}), to_array(${s}))`, x => array(ev(x)).map(b.evaluate));
    }
    case 'flatten': return node(`${s}[].a`, x => { const v = ev(x); return Array.isArray(v) ? project(v.flat(1), y => field(y, 'a')) : null; });
    case 'reverse_length': return node(`length(reverse(to_array(${s})))`, x => array(ev(x)).length);
    default: throw new Error('Unknown generator category');
  }
}

const datasets = [null, false, true, 0, -2, '', '😀', {}, [], [null, false, 0, [], {}],
  [3, 1, -2], [{a: null}, {a: false}, {a: 0}, {a: ''}, {b: 1}],
  [[{a: 1}, {a: 2}], [{a: 3}], null],
  {a: [{a: 1}, {a: 2}, {}], b: false, items: [null, 0, {a: 4}]},
  {a: {a: 'nested'}, b: [1, null, 2], items: []},
  {a: null, b: {a: 'fallback'}, items: [{a: [1]}, {a: []}]}];
export const cases = [];
export const evaluators = new Map();
export const expressions = new Set();
export const coverage = Object.fromEntries(categories.map(k => [k, 0]));
for (let i = 0; i < 512; i++) {
  const category = categories[i % categories.length];
  const e = generate(1 + next(4), i % categories.length);
  expressions.add(e.expression);
  evaluators.set(e.expression, e.evaluate);
  for (const data of datasets) {
    cases.push({ category, expression: e.expression, data, result: e.evaluate(data) });
    coverage[category]++;
  }
}
export const generatedQueries = cases.length;
// Explicit normative witnesses for previously reviewed jmespath.py 1.0.1
// disagreements. Do not suppress mismatches based on expression substrings or
// treat host-language bool/number equality, dict.update or ordering as an oracle.
// https://jmespath.org/specification.html : ordering, contains, merge, map.
export const fixtures = [
  {expression: 'a < b', data: {a: 'a', b: 'z'}, result: null},
  {expression: 'a >= b', data: {a: 1, b: 'z'}, result: null},
  {expression: 'a < b', data: {a: false, b: true}, result: null},
  {expression: 'contains(a, b)', data: {a: [true], b: 1}, result: false},
  {expression: 'contains(a, b)', data: {a: [1], b: true}, result: false},
  {expression: 'contains(a, b)', data: {a: [{x: true}], b: {x: 1}}, result: false},
  {expression: 'merge(a, b)', data: {a: {}, b: []}, error: 'invalid_type'},
  {expression: 'merge(a, b)', data: {a: {}, b: [['x', 1]]}, error: 'invalid_type'},
  {expression: 'merge(a, b)', data: {a: {x: 1}, b: {x: 2, y: 3}}, result: {x: 2, y: 3}},
  {expression: 'map(&a, items)', data: {items: [{a: 0}, {}, {a: false}]}, result: [0, null, false]},
  {expression: 'items[*].a', data: {items: [{a: 0}, {}, {a: false}]}, result: [0, false]},
  {expression: '(items[*].a)[0]', data: {items: [{a: [1, 2]}, {a: [3]}]}, result: [1, 2]},
  {expression: 'items[*].a[0]', data: {items: [{a: [1, 2]}, {a: [3]}]}, result: [1, 3]},
  {expression: 'map(&length(@), items)', data: {items: [[1], 0]}, error: 'invalid_type'},
  {expression: 'map(&length(@), items)', data: {items: [[1], []]}, result: [1, 0]},
];
cases.push(...fixtures.map(c => ({category: 'normative', ...c})));
export const corpusHash = createHash('sha256').update(JSON.stringify(cases)).digest('hex');
