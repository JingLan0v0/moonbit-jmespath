# Contributing

Use the compiler and Node.js versions in `toolchain.json`. Keep library logic
in MoonBit; Node-specific I/O belongs in `cmd/main/host.mbt`. Preserve public
resource limits and existing Git history. Read `AGENTS.md` and `docs/progress.md`
when resuming work.

Before submitting a change, run:

```text
moon fmt
moon info --target js
node scripts/verify.mjs
node scripts/conformance.mjs
node scripts/conformance.mjs --release
```

`moon` must be on PATH or set `MOON_BIN` to its executable and `MOON_HOME` to
the matching installation. On Windows, also run `./scripts/powershell-smoke.ps1`.
Use `scripts/moon.ps1` for individual Moon commands when using the local toolchain.
Commit generated `.mbti` changes only when the intended API changes.

Add behavioral regressions for bug fixes. Test normal values, boundary values,
and failure isolation. Runtime crash fixes must include a subprocess with a
timeout in both debug and release; a passing unit test alone is insufficient.
The official compliance suite is pinned and cached outside the repository.
New local regressions supplement it; never change upstream expected results
to hide incompatibilities. Keep README examples executable against committed data.

Report bugs with the version, expression, minimal non-sensitive JSON, expected
and actual result, target, build mode and exit code. Remove tokens and private
data before posting an issue on the existing GitHub repository.

For releases, follow `docs/publishing.md`. Do not equate a dry run, passing local
tests, successful CI, a registry upload or organizer acceptance. Record each
observed result separately in `docs/acceptance.md`.
## Equality property checks

`node scripts/verify.mjs` runs the deterministic equality suite against both
CLI builds. It checks 4,125 JSON pairs through five expressions each, using
canonical JSON as an independent expected-value calculation. It requires only
Node and the built CLI; no Python or local audit cache is needed.

To run it independently after building `cmd/main` with `moon build cmd/main
--target js` (and `--release` for release):

```sh
node scripts/equality-properties.mjs
node scripts/equality-properties.mjs --release
node scripts/equality-properties.mjs --replay _build/equality-debug-failure.json
```

Failures exit nonzero and save a single mismatched case, or the complete batch
when the process/transport fails. Replay executes those saved requests with their
expected results; it does not minimize cases automatically. Reports identify the
mode, actual count and replay status. Each run clears an older success receipt.
`JMES_CLI_PATH` may select a standalone artifact; full verification always pins
the artifacts it builds. CI uploads summaries and generated failure cases.

## Composition checks

`scripts/composition-properties.mjs` constructs 512 bounded expression trees
(depth 1–4) using seed `0x20261111`, each evaluated against 16 datasets. The
8,192 generated cases cover grouping, negation, functions, Boolean operators,
pipes, projections, indexes, filters, expression references and flattening.
Expressions may repeat; reports count unique expressions separately. Independent
JavaScript closures calculate expected values without parsing expression text or
calling a reference JMESPath implementation. This controlled grammar supplements
the official suite; it does not cover the entire language or resource limits.

Another 15 fixed cases distinguish map/projection behavior, grouped projections,
error isolation and previously reviewed Python-reference differences. Per the
[JMESPath specification](https://jmespath.org/specification.html), ordering of
nonnumeric values returns null, contains distinguishes booleans from numbers, and
merge requires every argument to be an object. These are explicit assertions,
not broad exception filters. Python/pip and local audit caches are not required.
Any new reference disagreement must be reduced and checked against the relevant
specification rule before changing an expectation or reporting a runtime bug.

Build the CLI as above, then run:

```sh
node scripts/composition-properties.mjs
node scripts/composition-properties.mjs --release
node scripts/composition-properties.mjs --replay _build/composition-debug-failure.json
```

Full verification includes both modes and compares actual counts, category
coverage and corpus SHA-256. Each subprocess has a 15-second timeout, a 192 MiB
Node old-space limit and at most 250 requests. These bounds apply to this test
workload, not every possible query. Failures save the mismatched case (including
expected error code where applicable), or the attempted batch if the process
fails. Replay and CLI overrides work like the equality harness; no automatic
minimization is performed. Setup failures also replace stale successful reports.
