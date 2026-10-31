# Resource contract (0.1.10)

The library targets MoonBit's JS backend. Resource errors are reported as
`JmesPathError`. These limits are not a wall-clock deadline or OS memory sandbox.

| Boundary | Default / hard cap | Behavior |
| --- | --- | --- |
| Expression length | 16,384 Unicode scalar values by default | Count before allocating tokenization array; configurable in Limits |
| Parser recursion and AST depth | 256 maximum | Checked while parsing and constructing nodes; configurable downward |
| Active evaluator calls | 128 hard cap | Separate from AST depth because function evaluation uses multiple host frames |
| Logical evaluation work | 1,000,000 by default | AST visits, equality visits/string comparisons, reductions, array membership, join and merge iterations |
| Materialized result elements | 100,000 by default | Cumulative array elements and unique object keys; referenced subtrees also have output guards |
| In-memory JSON input/result | Depth 256, root at 0; 1,000,000 expanded nodes | Iterative traversal; shared references count per occurrence |
| Output estimate | 16,777,216 UTF-16 units | Conservative estimate includes escaping and pretty indentation; checked before serialization |
| join intermediate string | 16,777,216 UTF-16 units | Length checked before allocation; final escaping may cause a stricter rejection |
| search_json text | 16,777,216 UTF-16 units | Checked before JSON parsing |
| JSON string token source | 8,388,608 UTF-16 units, excluding quotes | Checked before decoding; escape sequences count as written, not decoded |
| JSON lexical tokens | 1,000,000 per text | Containers, keys and scalar values counted before construction; duplicate keys also count |
| JSON text nesting | 1,024 open containers | Checked before recursive parsing; strings/escapes do not affect depth |
| CLI input | 16 MiB of bytes | Bounded read, strict UTF-8, optional BOM |
| Batch requests | 10,000 | Exceeding this rejects the whole batch |
| Successful batch responses combined | 500,000 nodes / 8,388,608 estimated UTF-16 units | Includes pretty formatting and wrapping; excess becomes an individual item error |
| Batch error messages | 128 UTF-16 units plus ... if truncated | Bounded errors remain possible after the success budget is exhausted |

JSON text parsing now preflights the budgets above in constant extra space,
then uses the pinned core parser for exact grammar and decoding. The same path
serves search_json, CLI batch input and expression JSON literals/quoted identifiers.
The public parse_json_bounded API applies transport budgets, not the per-query
depth/node limits. Thus a valid batch retains independent item checks.
Invalid or excessively nested **whole batch
text** cannot be split reliably and fails at the CLI transport boundary. In a
valid parsed batch, requests are checked independently. The outer response
array and `{ok,result}` count toward depth: a too-deep result becomes an item
error before printing the batch.

Each request starts with fresh evaluation state. A rejected large response
does not consume the success budget, allowing later smaller responses to fit.
If no success budget remains, later requests may also get `limit_exceeded`.
Logical work is not a CPU instruction counter: other core string routines and
shape preflight have bounded inputs but are not charged per machine instruction.

Since 0.1.10 ordering type scans charge one step per element; comparisons charge
one step plus one per Unicode iterator advance for strings. Sorting charges
two steps per element before allocating scratch copies and one per merge write.
The stable bottom-up merge sort propagates comparison errors immediately and
does not mutate caller data. sort/min/max and their _by variants share the
budget. Scratch storage is O(n); this is not a wall-clock or memory sandbox.
Long common prefixes or large legitimate sorts may now exceed max_steps where
earlier versions succeeded. Trusted callers may choose a higher valid budget;
untrusted callers should retain bounded operation. Exhaustion remains an
isolated per-item limit_exceeded error in a decoded batch.

Since 0.1.5, `to_number` scans string characters against a scalar-number alphabet
before calling the JSON parser and charges each scanned character to max_steps.
Non-numeric arrays/objects encoded as strings return null without materializing
their contents. Extremely long numeric strings can now return limit_exceeded.

The roughly 12 MB escaped-string crash left open in 0.1.5 is now rejected before
decoding by the string-token budget. Very wide texts are rejected by the lexical
token budget, including duplicate object keys. These additional restrictions can
reject some inputs previously accepted within the overall 16 MiB byte cap.
They intentionally bound decoder work; they do **not** guarantee a universal
192 MiB peak heap. Host memory exhaustion remains uncatchable as a per-item error.
Applications still need appropriate ingress and worker memory/time controls.
An oversized transport returns limit_exceeded for the whole command (exit 2,
empty stdout), rather than pretending to preserve undecoded batch items.

Use `stringify_bounded` to serialize library results. It validates and renders
the same value. Mutating returned JSON and invoking a different serializer is
outside that guarantee. Non-finite numbers fail with `invalid_value` rather
than becoming invalid JSON text. These are resource/representation limits,
not JMESPath syntax extensions.

Since 0.1.9 each evaluated scalar result must be finite before its parent runs.
Previously `type(sum(@))` or a comparison could conceal an overflow that direct
`sum(@)` correctly rejected. Such queries now consistently return invalid_value.
The check does not evaluate skipped boolean branches. Floating-point operations
remain IEEE binary64, not exact decimal arithmetic; the current avg uses a
running sum, so it rejects an overflowing sum even when a mathematical average
could be finite. This release does not claim improved numerical precision.

## Regression inputs

- 4,000 exclamation marks plus @: the September parser failure.
- 255 nested to_array calls: the separately reproduced October evaluator crash.
- Thirty [@,@] stages: exponential output expansion despite a small syntax tree.
- Expanded results passed to to_string, equality and contains.
- A large join separator, deep JSON data/literals, non-finite arithmetic, and
  cumulative large batch results followed by a small normal request.

`node scripts/verify.mjs` runs both debug and release subprocesses. The
adversarial harness uses a 15-second timeout and a 192 MiB V8 old-space cap.
Those are harness safeguards, not implied runtime features of the CLI.
