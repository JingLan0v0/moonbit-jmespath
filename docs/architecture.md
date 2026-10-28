# Architecture

```text
expression -> bounded lexer -> Pratt parser -> immutable AST
                                                |
JSON -------------------------------------------+
                                                v
                                       bounded evaluator -> JSON
                                                |
                                     standard function registry
```

The root package contains five layers. `lexer.mbt` converts Unicode scalar
input into located tokens. `parser.mbt` applies JMESPath precedence and records
projection boundaries in the AST. `evaluator.mbt` handles navigation,
projection, filtering, boolean semantics, and resource accounting.
`functions.mbt` implements the standard function set and expression references.
`api.mbt` exposes compiled, one-shot, text, and batch entry points.

The parser is independent from JSON input. A `Compiled` value can be reused
with many documents. Evaluation state is created per search, so step and result
counters never leak between calls.

## Projection model

JMESPath projections differ from ordinary array mapping because later path
components attach to the innermost active projection, while flattening creates a
new projection boundary. The AST retains this distinction instead of inferring
it from runtime JSON types. Official indices, wildcard, filter, and multiselect
tests cover this behavior.

## Trust boundaries

The library performs no I/O. The Node.js adapter in `cmd/main/host.mbt` is the
only layer that reads files, stdin, process arguments, or writes output. It
reads no more than 16 MiB plus one probe byte and decodes UTF-8 strictly. Query
limits are validated before parsing; parser recursion and AST depth are both
bounded. The evaluation step and cumulative materialized-result counters check
remaining capacity before incrementing or appending to an output collection.

Active evaluation calls have a separate 128-level cap because a function call
uses several runtime frames per AST node. `equality.mbt` walks JSON using an
explicit stack and charges repeated subtrees to query work. `json_safety.mbt`
walks one child at a time to bound JSON depth, expanded nodes and estimated
serialized size, including pretty indentation. `api.mbt` reserves batch error
space and checks successful replies including their envelope before appending.
See `resource-limits.md` for the exact contract and its limitations.

The conformance runner downloads only a pinned upstream revision into the OS
temporary directory. Release archives contain the runner and notices, but not
the downloaded vectors.
