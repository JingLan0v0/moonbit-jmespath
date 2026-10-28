# Library, CLI and error contracts

The current release supports MoonBit's JS backend. Node.js supplies the CLI
host. The library itself has no file/network I/O. Use `toolchain.json` for the
verified compiler/runtime versions; a newer compiler is not automatically tested.

## Reproducible library example

In this checkout run `moon run examples/library --target js` (or
`.\scripts\moon.ps1 run examples/library --target js` in PowerShell).
The committed `examples/library/main.mbt` and `moon.pkg` form a complete program.
Its output is:

```text
["Ada"]
[]
error: invalid_type
```

In your own MoonBit module, first run `moon add JingLan0v0/jmespath`, then copy
the example's package imports and function. Use `--target js`. Keep the generated
dependency version in your module configuration for reproducibility.

`compile` validates syntax/limits once; `Compiled::search` checks each input and
starts fresh evaluation counters. `search` compiles and evaluates once.
`search_json` parses JSON text before searching. `stringify_bounded` validates
the expanded JSON before serializing it. None of these APIs mutate input JSON.
Treat compiled queries and input collections as read-only while evaluating.

Catch `JmesPathError(d)` and branch on `d.code`, not the human-readable message.
`d.offset` is a zero-based Unicode character index for lexer/parser diagnostics;
it is not a UTF-8 byte offset or UTF-16 editor index. Runtime, JSON and aggregate
limit errors generally use 0 because no precise expression span is available.
Batch error messages may be truncated; codes remain stable.

| Code | Meaning / caller action |
| --- | --- |
| `syntax` | Invalid expression; correct the expression |
| `invalid_json` | Invalid JSON text; correct the input |
| `invalid_type` | Function received an unsupported type |
| `invalid_arity` | Incorrect function argument count |
| `unknown_function` | Unsupported function name |
| `invalid_value` | Invalid limits/value, zero slice step or non-finite result |
| `invalid_batch` | Top level is not an array or an entry lacks valid fields |
| `limit_exceeded` | A documented resource budget was exhausted |

See [resource-limits.md](resource-limits.md) before accepting untrusted input.
Budgets provide bounded operations/input/output, not an OS isolation boundary.

## CLI automation

Run `moon run cmd/main --target js -- --help` for options. `--compact` changes
formatting, not values. FILE defaults to stdin; `-` explicitly selects stdin.
The CLI's `--` ends its option parsing (after Moon's own `--` separator).

| Outcome | Exit | stdout | stderr |
| --- | --- | --- | --- |
| Single query succeeds, including a null result | 0 | JSON result | empty |
| Batch processed, including per-item errors | 0 | JSON response array | empty |
| Query error / unreadable file / malformed batch transport | 2 | empty | diagnostic |

Always inspect each batch `ok` field. A valid null result is `{ok:true,result:null}`,
not an error. Batch results preserve input order. JSON syntax or excessive
nesting of the transport itself cannot be isolated to individual requests.

Try `moon run cmd/main --target js -- --batch examples/batch.json`. It returns
three entries: `Ada`, an `invalid_arity` error, and `fallback`; exit status is 0.

## Compatibility edge cases

Null multi-select input stays null; other false-like values (false, zero, an
empty string/array/object) still evaluate the selected expressions. Projections
omit null results; `map` retains them. Subexpressions evaluate the right side
using the left result, including null, so fallback functions can operate.

These regressions supplement the pinned official vectors. Behavior was checked
against the [JMESPath specification](https://jmespath.org/specification.html)
and the [official Python interpreter](https://github.com/jmespath/jmespath.py/blob/develop/jmespath/visitor.py);
no interpreter source is included. Passing a finite suite is not proof of
complete compatibility for every possible expression or input.
