# Performance benchmarks

Run the benchmark from a Git checkout with the MoonBit and Node.js versions
in `toolchain.json`. Put `moon` on PATH or set `MOON_BIN` and `MOON_HOME` to the
same installation.

```sh
node scripts/benchmark.mjs
node scripts/benchmark.mjs --debug
```

The default build mode is release. Each run builds the benchmark and the CLI
for the JS backend. It writes `_build/benchmark-release-summary.json` or
`_build/benchmark-debug-summary.json` with raw samples, min/median/max,
workload sizes, toolchain and host details, source SHA and working tree status.
Save a copy of the report before running another version in the same mode.

| Workload | Fixed input | Timed operation |
| --- | --- | --- |
| Compile small and large | 26 and 15,401 ASCII characters | Compile an expression and read its source |
| Compiled filter | Three records | Search with a compiled expression, including JSON checks |
| Large sort | 8,192 integers in a fixed permutation | Sort with a compiled expression |
| Long string | 524,288 UTF-16 units containing ASCII, CJK and emoji | Search with compiled `length(@)` |
| Compact serialization | 60,000 strings | Bounded serialization and output length |
| Batch compile | 512 copies of the same expression | Compile each expression |
| Batch repeated and distinct | 512 requests with equal-length expressions and identical results | Process the complete in-memory batch |
| Large batch | 8,192 repeated requests | Process the complete in-memory batch |
| Node startup | Empty program | Launch a fresh Node process |
| CLI filter and batch | Three records or 512 requests on stdin | Launch the CLI, decode input, query and write JSON |

Library inputs are prepared outside the timer. Each case has a dedicated
Node process and uses three warm-up samples and nine measured samples. A
sample averages the number of operations recorded in `iterationsPerSample`.
The harness checks expected output before timing and consumes a checksum
during the loop. Its `peakRssKiB` measures the full process, including setup
and warm-up. [Node.js resource usage reference](https://nodejs.org/docs/latest-v24.x/api/process.html#processresourceusage)

CLI samples time fresh child processes and check their JSON output after each
sample. Two warm-up launches precede nine measured launches. The Node startup
case gives a separate reference for interpreting this wall time. CLI and
startup peak RSS are omitted. Builds are timed separately.

For a change comparison, run both revisions with the same mode, toolchain and
machine under similar load. Compare the raw distributions and memory alongside
the median. Batch compilation in isolation provides a comparison point for
total batch cost. Different allocations and garbage collection can affect
each measurement. Use the regular verification command to check semantics and
resource boundaries. Performance measurements have no CI time threshold.

## Batch reuse in 0.1.19

The single-entry reuse slot improved repeated requests on a Windows x64 host
using Node.js 24.14.0 and MoonBit 0.10.20+65efd5b93. The comparison used the
release builds from `7039b33` and `9ee0f09`. Each workload ran in fresh child
processes for five pairs, alternating which revision ran first. Values are
the median of the five run medians and the median of the five process peaks.

| Batch workload | Before (ms) | After (ms) | Before peak RSS (KiB) | After peak RSS (KiB) |
| --- | ---: | ---: | ---: | ---: |
| 512 repeated expressions | 1.134 | 0.569 | 55,908 | 54,632 |
| 512 distinct expressions | 1.134 | 1.154 | 55,704 | 55,560 |
| 8,192 repeated expressions | 17.020 | 7.463 | 132,176 | 120,656 |

The distinct-expression paired timing ratios ranged from 0.984 to 1.053.
The chosen reuse slot holds one compiled expression of up to 1,024 UTF-16
units for the duration of the batch. It targets groups of identical requests
with little retained state. These measurements describe the listed workloads
on this host.
