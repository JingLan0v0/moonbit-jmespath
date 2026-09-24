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
limits input size and decodes UTF-8 strictly. Query resource limits stop deeply
nested expressions and large projections before they become unbounded work.

The conformance runner downloads only a pinned upstream revision into the OS
temporary directory. Release archives contain the runner and notices, but not
the downloaded vectors.
