# MoonJMES

[简体中文](README.zh-CN.md) | English

[![CI](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml/badge.svg)](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonJMES is a native MoonBit implementation of
[JMESPath](https://jmespath.org/), the standard query language for JSON. It
turns nested API responses, cloud inventories, audit records, and configuration
files into smaller JSON results without embedding JavaScript or shipping data
to a service.

The engine passes **892/892 cases in the official JMESPath compliance suite**
at pinned revision `53abcc37901891cf4308fcd910eab287416c4609`. The result is
reproducible with `node scripts/conformance.mjs`; see
[docs/conformance.md](docs/conformance.md).

## Why this project

MoonBit already has general JSON and jq-style tools, but the Mooncakes search at
project start returned no JMESPath implementation. JMESPath is widely used in
cloud and automation tooling, has a formal grammar, and has a language-neutral
test suite. That gives this project a clear ecosystem boundary and an objective
definition of compatibility.

## Features

- identifiers, quoted identifiers, current node, JSON and raw-string literals
- object/list wildcards, flattening, projections, filters, indexes, and slices
- pipes, comparisons, boolean expressions, multi-select lists and hashes
- all standard scalar, collection, conversion, and expression-reference
  functions, including `map`, `sort_by`, `min_by`, and `max_by`
- reusable compiled expressions and one-shot JSON/text APIs
- batch execution with per-request structured errors
- configurable expression, AST depth, evaluation-step, and result limits
- a file/stdin CLI with deterministic JSON output
- pure MoonBit engine; Node.js is used only by the CLI host adapter

## Quick start

Install the published library from Mooncakes:

```bash
moon add JingLan0v0/jmespath
```

The package documentation is available at
[mooncakes.io/docs/JingLan0v0/jmespath](https://mooncakes.io/docs/JingLan0v0/jmespath).

`moon add` installs a library dependency, not a global CLI executable. This
release supports the **JS backend**; CI pins MoonBit `0.10.14+7d59c7ec9` and
Node.js `24.14.0` (see `toolchain.json`). To run the CLI, clone this repository
and query the included file:

```bash
git clone https://github.com/JingLan0v0/moonbit-jmespath.git
cd moonbit-jmespath
moon run cmd/main --target js -- "instances[?state == 'running'].{id: id, zone: zone}" examples/cloud-inventory.json
```

Or pipe JSON through standard input:

```bash
echo '{"items":[{"name":"A","price":9},{"name":"B","price":12}]}' \
  | moon run cmd/main --target js -- 'items[?price >= `10`].name' -
```

Result:

```json
[
  "B"
]
```

### Library API

Import the package in `moon.pkg`:

```moonbit
import {
  "JingLan0v0/jmespath" @jmespath,
  "moonbitlang/core/json",
}
```

```moonbit
let input = @json.parse("{\"people\":[{\"name\":\"Ada\",\"age\":36}]}")
let query = @jmespath.compile("people[?age >= `18`].name")
let result = query.search(input)
```

Public entry points: `compile`, `Compiled::search`, `search`, `search_json`, and
`search_batch`. Use `stringify_bounded(result, pretty=true)` to serialize library
results with the same output safeguards as the CLI.

The fragment above belongs inside a function that handles or propagates errors.
For a complete executable with imports, custom limits, query reuse and error
handling, run `moon run examples/library --target js` from this checkout.
See [the API and error guide](docs/usage.md).

### Batch API and CLI

Batch input is an array of independent requests:

```json
[
  {"expression":"name","data":{"name":"Ada"}},
  {"expression":"length()","data":null}
]
```

```bash
moon run cmd/main --target js -- --batch examples/batch.json
```

Each response has `ok: true` and `result`, or `ok: false` and a structured
`error`. Invalid expressions and malformed request entries therefore do not
discard other batch results. Invalid top-level JSON still exits with code 2.
Batch mode exits **0 even when individual requests fail**: inspect every `ok`
field. The included file adds a third successful fallback query after the error.

## Three runnable scenarios

The [`examples`](examples/README.md) directory covers cloud inventory selection,
deployment-policy findings, and cost-report sorting. Run all three on Windows
with `./examples/run.ps1`; the script compares each result with committed JSON.

## Resource limits and errors

Defaults are 16,384 expression characters, AST depth 256, 1,000,000 evaluation
steps, and 100,000 cumulatively materialized result elements. Custom limits
must be valid, and AST depth cannot exceed 256. Batch input is capped at
10,000 requests; the CLI reads at most 16 MiB and decodes UTF-8 strictly,
accepting an optional UTF-8 BOM.

Version 0.1.3 also bounds active evaluation calls to 128, checks JSON input and
output iteratively, and limits aggregate batch successes. The JSON guard limits
depth to 256 (root at zero), expanded nodes to 1,000,000 and the conservative
output estimate to 16 Mi UTF-16 units. See [the exact resource contract](docs/resource-limits.md).

Errors use stable categories: `syntax`, `invalid_json`, `invalid_type`,
`invalid_arity`, `invalid_value`, `unknown_function`, `invalid_batch`, and
`limit_exceeded`. A library caller receives `JmesPathError`; the CLI writes a
single diagnostic to stderr and exits with code 2.
This describes single-query or whole-batch failures; per-item batch errors stay
in the JSON response on stdout, as described above.

## Verification

```bash
moon fmt --check
moon check --target js
moon test --target js
moon info --target js
node scripts/conformance.mjs
node scripts/conformance.mjs --release
node scripts/verify.mjs
```

The GitHub Actions matrix runs on Windows and Ubuntu with the pinned compiler.
Architecture and trust boundaries are in
[docs/architecture.md](docs/architecture.md).

## September acceptance bug fixed in 0.1.2

The rejected release could crash while parsing an expression made of 4,000
`!` prefixes followed by `@` (4,001 characters, below the default length
limit). The parser checked AST depth only after recursion, so a three-request
batch produced no output and exited with status 1 in both debug and release.
The parser now enforces recursion depth while building the AST and checks the
depth of each constructed node. The offending request returns a structured
`limit_exceeded` error; the requests before and after it still return results.
Single-query CLI mode exits with status 2 and a diagnostic instead of crashing.
Regression tests cover the exact batch shape, single-query mode, nested
grouping and the allowed depth boundary in both CLI builds. The original
0.1.1 release remains available for historical comparison.

A Chinese project overview for contest information review is available in
[docs/project-introduction.zh-CN.md](docs/project-introduction.zh-CN.md).

## Project boundary

### October hardening in 0.1.3

The October audit reproduced a separate stack overflow in 0.1.2: 255 nested
`to_array(...)` calls passed AST validation but crashed the debug evaluator.
Execution now checks active call depth before descending. Short repeated
`[@,@]` pipes could also expand exponentially during serialization while barely
increasing the old result counter. An iterative output guard now counts each
expanded occurrence; iterative JSON equality consumes the query work budget.
`join` checks size before allocation, object producers charge keys before
insertion, and batch successes share an output budget with room reserved for
errors. Non-finite arithmetic returns `invalid_value` instead of invalid JSON.

Verification covers 52 unit tests, three scenarios, and, in **each** CLI build
mode, 33 adversarial checks plus 256 deterministic grammar mutations. Test
subprocesses have a timeout and heap cap. CI enforces warning-free checks and
exact official error categories in both modes, on Windows and Ubuntu, and saves
downloadable JSON evidence. See [acceptance evidence](docs/acceptance.md) and
[competition status](docs/competition.md).

MoonJMES implements the JMESPath specification. The 0.1.x line has no custom
query extensions, keeping results portable across compliant JMESPath
implementations. Version [0.1.10 is published on Mooncakes](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.10)
and verified from a fresh consumer in debug and release. Older versions remain available
for historical comparison. See [CHANGELOG.md](CHANGELOG.md).

## Null semantics and usability fixes in 0.1.4

An additional audit found behavior not covered by the pinned official vectors:
multi-select lists/hashes must preserve a null input, while a subexpression must
still evaluate its right-hand function on a null left result. For example,
`missing.not_null(@, 'fallback')` now returns `"fallback"` for `{}`, and `[foo]`
returns `null` for null input. Added regressions cover projections, `map`, error
propagation, and non-null false-like values. Existing resource guards remain.

Quick-start commands now use committed input files, a complete public API
example runs in both modes, and the PowerShell scenario runner works outside
the checkout. See [CHANGELOG.md](CHANGELOG.md), [usage](docs/usage.md) and
[contributing](CONTRIBUTING.md). Release evidence is in [acceptance.md](docs/acceptance.md).

## Numeric conversion memory fix in 0.1.5

`to_number` no longer parses arbitrary encoded arrays/objects merely to return
null. An encoded 4.8 MB object array crashed 0.1.4 under a 192 MiB test heap in
both modes; scalar prefiltering now preserves the batch's neighboring results.
Numeric scanning also consumes the work budget. This is a conversion fix, not
a universal memory guarantee: core transport decoding can still exhaust a
constrained heap. See [resource limits](docs/resource-limits.md) and the
[release evidence](docs/acceptance.md).

## Decoder preflight in 0.1.6

The 12 MB escaped-string case left open in 0.1.5 now fails before JSON decoder
allocation. Constant-space lexical scanning caps raw string tokens at 8 Mi
UTF-16 units, lexical tokens (including keys) at 1,000,000, and nesting at 1,024.
This intentionally adds restrictions within the overall 16 MiB input cap.
Single-query, batch transport and expression JSON decoding share this check.
The public `parse_json_bounded` supports safe text ingestion by library callers.
Whole-transport failures return `limit_exceeded`, exit 2, empty stdout; item
isolation still applies once the batch is decoded. Regression tests exercise
both modes under the same 192 MiB test heap. This is not a universal peak-memory
guarantee. See [resource limits](docs/resource-limits.md) and [evidence](docs/acceptance.md).

## CLI output and diagnostic fixes in 0.1.7

Output failures (including a downstream pipe closing early) now exit 2 rather
than throwing an unhandled Node exception. If stderr is available, a short I/O
diagnostic is emitted; if both streams fail, only exit status can report it.
Diagnostics escape embedded controls, line separators and bidi formatting so
invalid options cannot create forged log lines or terminal commands. Normal
JSON stdout is unchanged. Output may be partial if a destination fails during
writing; consumers must check exit status. Five new subprocess cases pass in
both modes, on Windows/Ubuntu and from the downloaded release. See
[usage](docs/usage.md) and [release evidence](docs/acceptance.md).

## Unicode ordering corrected in 0.1.8

String ordering now follows Unicode code points rather than UTF-16 code units,
fixing incorrect results across BMP and supplementary-plane characters in
`sort`, `min`, `max` and their `_by` variants. For example U+E000 must precede
U+10000. The comparator uses iterators without allocating character arrays;
there is no locale collation or normalization. Regression cases include empty
strings, prefixes, ties, combining sequences and U+10FFFF. Numeric extremes and
existing behavior also pass. See [usage](docs/usage.md) and [evidence](docs/acceptance.md).

## Intermediate overflow consistency in 0.1.9

Non-finite scalar results are now rejected before parent expressions consume
them. Previously `type(sum(@))` on `[1e308,1e308]` succeeded while direct sum
correctly failed. Arithmetic/conversion overflow can no longer hide behind a
type check, comparison or collection wrapper. Lazy boolean branches remain
lazy, batches isolate the error and compiled queries remain reusable.
This enforces the finite-JSON policy; it does not improve floating-point
precision or change the running-sum algorithm for avg. See
[resource limits](docs/resource-limits.md) and [evidence](docs/acceptance.md).

## Ordering work budgets in 0.1.10

Ordering scans, comparisons and Unicode iterator advances now consume max_steps
across sort/min/max and their _by variants. Stable bottom-up merge sorting also
meters scratch copies and merge writes, and stops immediately on budget errors.
Long common prefixes can no longer perform unmetered comparison work. Inputs
stay unchanged, equal-key order is preserved, and later batch items still run.
Large legitimate sorts may now need a higher explicitly chosen trusted budget;
this is an intentional tightening, not a wall-clock guarantee. See
[resource contract](docs/resource-limits.md) and [release evidence](docs/acceptance.md).

## License

Apache-2.0. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the
verification-time relationship with the official test suite.
