# MoonJMES

[简体中文](README.zh-CN.md)

MoonJMES is a MoonBit library and command-line tool for querying JSON with
JMESPath. Use it to filter records, extract fields, project nested data, and
sort reports. It supports the JS backend, with Node.js as the CLI host.

The published release is **0.1.20**. [Mooncakes package](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.20) · [Changelog](CHANGELOG.md)

## Install the library

From an existing MoonBit module, install the exact release.

```sh
moon add JingLan0v0/jmespath@0.1.20
```

Use this `moon.pkg` for the minimal executable.

```moonbit
import {
  "JingLan0v0/jmespath" @jmespath,
}

pkgtype(kind: "executable")
```

In the same package, create `main.mbt`.

```moonbit
fn main raise {
  let input = @jmespath.parse_json_bounded("{\"items\":[{\"name\":\"Ada\"}]}")
  let query = @jmespath.compile("items[*].name")
  println(@jmespath.stringify_bounded(query.search(input)))
}
```

Run `moon run . --target js` from that package. It prints
`["Ada"]`. The repository also includes a complete example with custom limits,
query reuse, and error handling. [Library example](examples/library/main.mbt) · [API guide](docs/usage.md)

## Run the CLI from source

Use MoonBit `0.10.20+65efd5b93` and Node.js `24.14.0` for the pinned build.
Older MoonBit versions such as `0.10.14` cannot compile the current source.
[Toolchain configuration](toolchain.json) · [Official installation instructions](https://www.moonbitlang.com/download/)

```sh
git clone https://github.com/JingLan0v0/moonbit-jmespath.git
cd moonbit-jmespath
moon run cmd/main --target js -- --compact "instances[?state == 'running'].id" examples/cloud-inventory.json
```

Expected output is `["i-101","i-102","i-104"]`. Pass `-` as the input path to read
JSON from stdin. On Windows, `scripts/moon.ps1` can select the pinned local
toolchain. [PowerShell commands](examples/README.md#windows-powershell) · [CLI usage](docs/usage.md#cli-automation)

## Try the checked examples

```sh
node examples/demo.mjs
```

| Scenario | Result |
| --- | --- |
| Cloud inventory | IDs and zones for running production instances |
| Deployment policy | Blocked services and their nested reason codes |
| Cost report | Services sorted by monthly cost |

The demo asserts all three results against committed JSON. It also checks the
quick start query and a batch that returns `before`, `limit_exceeded`, then
`after`. Add `--release` to run the release build. [Inputs, queries, and expected results](examples/README.md)

Batch input is a JSON array of `{"expression":"…","data":…}` requests. When the
batch is accepted, the CLI exits 0 and each response has its own `ok` flag and
result or error. An invalid outer JSON document fails the whole invocation with
exit 2 and empty stdout. [Batch API and error contract](docs/usage.md#cli-automation)

## Limits and compatibility

Default query limits include 16,384 Unicode scalars for the expression, AST
depth 256, one million work steps, and 100,000 materialized result elements.
The evaluator also caps active call depth at 128. The CLI reads at most 16 MiB
of input, and a batch accepts at most 10,000 requests. Input and output shape
checks bound JSON expansion. [Resource limits](docs/resource-limits.md)

Function error positions count Unicode scalars from zero. Results can share
collections with caller input, and reused compiled queries keep independent
evaluation state. [Diagnostics and ownership](docs/usage.md)

## Verify a checkout

```sh
node scripts/verify.mjs
```

Windows and Ubuntu CI use this command. Debug and release each run 79 unit
tests, 892 pinned official JMESPath cases, the demos and resource-limit
regressions. Windows also checks PowerShell. The command writes
`_build/verification-summary.json`. [Verification setup](CONTRIBUTING.md#verification) · [GitHub Actions](https://github.com/JingLan0v0/moonbit-jmespath/actions/workflows/ci.yml)

The acceptance log records test results by commit, historical fixes, archive
checks and fresh installation evidence. [Acceptance evidence](docs/acceptance.md) · [Performance benchmarks](docs/performance.md)

## License and references

MoonJMES is an independent implementation of the public JMESPath specification.
Pinned upstream vectors are downloaded for verification. The project is
licensed under Apache-2.0. [License](LICENSE) · [Third-party notices](THIRD_PARTY_NOTICES.md)
