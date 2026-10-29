# Resource contract (0.1.5)

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
| CLI input | 16 MiB of bytes | Bounded read, strict UTF-8, optional BOM |
| Batch requests | 10,000 | Exceeding this rejects the whole batch |
| Successful batch responses combined | 500,000 nodes / 8,388,608 estimated UTF-16 units | Includes pretty formatting and wrapping; excess becomes an individual item error |
| Batch error messages | 128 UTF-16 units plus ... if truncated | Bounded errors remain possible after the success budget is exhausted |

JSON text parsing uses the pinned core parser's nesting ceiling (1,024) before
the library checks parsed values. Invalid or excessively nested **whole batch
text** cannot be split reliably and fails at the CLI transport boundary. In a
valid parsed batch, requests are checked independently. The outer response
array and `{ok,result}` count toward depth: a too-deep result becomes an item
error before printing the batch.

Each request starts with fresh evaluation state. A rejected large response
does not consume the success budget, allowing later smaller responses to fit.
If no success budget remains, later requests may also get `limit_exceeded`.
Logical work is not a CPU instruction counter: core string/sort routines and
shape preflight have bounded inputs but are not charged per machine instruction.

Since 0.1.5, `to_number` scans string characters against a scalar-number alphabet
before calling the JSON parser and charges each scanned character to max_steps.
Non-numeric arrays/objects encoded as strings return null without materializing
their contents. Extremely long numeric strings can now return limit_exceeded.

The 16 MiB transport cap does **not** guarantee a 192 MiB peak heap. In this
audit, a roughly 12 MB heavily escaped string exhausted that artificial test
heap during core JSON decoding even without conversion. In-memory limits are
checked after decoding; host out-of-memory termination is not catchable as a
per-item query error. Services accepting untrusted JSON must also set an
appropriate ingress size and isolate worker processes with host memory/time
limits. The harness heap cap proves the recorded cases only, not every input
under the transport cap. This limitation remains outside the 0.1.5 conversion fix.

Use `stringify_bounded` to serialize library results. It validates and renders
the same value. Mutating returned JSON and invoking a different serializer is
outside that guarantee. Non-finite numbers fail with `invalid_value` rather
than becoming invalid JSON text. These are resource/representation limits,
not JMESPath syntax extensions.

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
