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

To run this repository's CLI, install MoonBit and Node.js, then query a file:

```bash
moon run cmd/main --target js -- "instances[?state == 'running'].{id: id, zone: zone}" inventory.json
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
`search_batch`.

### Batch API and CLI

Batch input is an array of independent requests:

```json
[
  {"expression":"name","data":{"name":"Ada"}},
  {"expression":"length()","data":null}
]
```

```bash
moon run cmd/main --target js -- --batch requests.json
```

Each response has `ok: true` and `result`, or `ok: false` and a structured
`error`. Invalid expressions and malformed request entries therefore do not
discard other batch results. Invalid top-level JSON still exits with code 2.

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

Errors use stable categories: `syntax`, `invalid_json`, `invalid_type`,
`invalid_arity`, `invalid_value`, `unknown_function`, `invalid_batch`, and
`limit_exceeded`. A library caller receives `JmesPathError`; the CLI writes a
single diagnostic to stderr and exits with code 2.

## Verification

```bash
moon fmt --check
moon check --target js
moon test --target js
moon info --target js
node scripts/conformance.mjs
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

MoonJMES implements the JMESPath specification. The 0.1.x line has no custom
query extensions, keeping results portable across compliant JMESPath
implementations. The 0.1.2 release includes early parser depth checks and
regression tests for the September acceptance rejection's 4,001-character
unary expression. See [CHANGELOG.md](CHANGELOG.md).

## License

Apache-2.0. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the
verification-time relationship with the official test suite.
