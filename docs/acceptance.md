# MoonJMES acceptance evidence

## 0.1.5 conversion allocation audit (2026-10-29)

`to_number` in 0.1.4 parsed arbitrary JSON strings before checking their type.
A string encoding 600,000 small objects (~4.8 MB decoded) exhausted a 192 MiB
test heap during conversion, while querying its string type succeeded. The
fix rejects nonnumeric characters before parsing and meters numeric scanning.
No arbitrary JSON subtree can now be allocated by this conversion.

Local verification: 39 unit tests; three scenarios and the complete API example;
both CLI modes with 22 adversarial checks and 256 grammar mutations; official
suite 892/892 in both modes; PowerShell smoke. The new conversion batch returns
before/null/after with exit 0. The exact numeric grammar remains parser-validated.

Scope: a larger ~12 MB escaped input also exhausted the test heap during core
transport decoding. That is a separate, documented host-memory limitation, not
claimed fixed by 0.1.5. See resource-limits.md. Remote and publication evidence
for 0.1.5 is pending at this source checkpoint.

## Additional 0.1.4 semantic and usability audit (2026-10-28)

Found two semantic defects beyond the 892 pinned upstream cases: multi-selects
were constructing collections for null input, and subexpressions skipped
right-hand functions after null left results. Both are corrected with unit and
CLI regressions, including projection/map cardinality and error propagation.
Existing resource guards and September/October adversarial regressions remain.

Local verification: **37/37** unit tests with warnings denied; three scenarios;
complete library example in debug/release; null semantics, batch example and
all previous CLI checks in both modes; **20 adversarial checks and 256 grammar
mutations per mode**; official suite **892/892 in each mode**. PowerShell smoke
also runs all scenarios from outside the checkout and checks caller directory
restoration. README command paths now refer to committed inputs. The API guide
documents diagnostic offsets, JS backend and batch exit semantics; contributor
instructions define how to add regressions and verify future releases.

### Verified release evidence (2026-10-29)

- Source commit `bedcd49470e1e7c1e7c5ea80629c861beca7d6e2` is on public main,
  with identical local/remote Git tree and commit IDs. Its parent is `224932c`;
  history is retained without force push.
- [CI run 40833672916](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40833672916)
  passed on Windows and Ubuntu. Both acceptance evidence artifacts were uploaded.
  [Development setup run 40833672917](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40833672917)
  also passed with the pinned toolchain.
- Mooncakes preflight returned 202 / dry-run success. Formal publication returned
  **200 OK** for `JingLan0v0/jmespath@0.1.4` on 2026-10-29.
- Archive: 61 files, no credentials, Git metadata, build output or toolchain/cache
  directories. SHA-256: `74310ce30c30af5760de7ce7601a7efb7943a7172b5cc3f7a2d65b6e675573a4`.
  A fresh extraction passed the complete verification script before publication.
- A fresh consumer installed exact registry version 0.1.4 and passed debug/release
  calls for null multi-selects, missing-field fallback/conversion and `map`;
  ordinary queries, September parser isolation, evaluator depth, output expansion
  and bounded serialization also passed. This used the downloaded package.
- [Published package](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.4).
  The following documentation-only Git commit records the observed evidence;
  it is not a second registry release. Organizer final acceptance remains pending.

## October 0.1.3 audit (2026-10-28)

The participant supplied the organizer's October initial-approval notice for
this repository. Final acceptance remains an organizer decision.

The audit reproduced a **new** debug evaluator crash in 0.1.2 using 255 nested
`to_array` calls. The syntax fits the old AST limit but exhausted the runtime
stack (exit 1). It also identified exponentially expanded output from repeated
`[@,@]` pipes. Both are covered by new real-process regressions, alongside the
September 4,001-character input. Core equality is now iterative and work-bounded;
JSON traversal, join and batch output have guards before unsafe expansion.

Local verification on the pinned JS toolchain passes 34 unit tests with compiler
warnings denied, three scenarios, and debug/release CLI tests. Each CLI mode
runs 20 adversarial checks and 256 deterministic grammar mutations. Valid
requests before/after an oversized query remain present; standalone resource
errors exit 2 with no stdout. Tests also cover response-envelope depth, reused
compiled values, object budgets, equality semantics and non-finite output.

The pinned official suite passes **892/892 in debug and 892/892 in release**
locally, including exact error categories. The PowerShell pipeline/version
smoke test passes. Local summaries are generated in `_build/` and CI will
upload fresh summaries associated with its exact commit SHA.

### Verified release and remote evidence

- Source commit: `7d84925484559cedd81121da75161dfe3e64f2c7`. Its Git tree and
  commit ID were verified identical locally and on public `main`. The commit
  follows `f0df943`; earlier history is retained without a force push.
- [GitHub Actions run 40682667445](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40682667445)
  completed successfully on that exact commit. Windows and Ubuntu both passed
  verification, debug/release official compliance and generated-interface
  checks. The Windows PowerShell step also passed.
- The run contains `acceptance-windows-latest` and `acceptance-ubuntu-latest`
  artifacts with JSON summaries. Artifacts have a 30-day retention policy;
  the commit, workflow and this record preserve how to reproduce the checks.
- Mooncakes preflight returned **202 Accepted / Dry run completed successfully**.
  The archive contains 55 files; no credentials, toolchains, `.git`, `_build`
  or dependency cache. A separately extracted archive passed the full local
  verification, including all adversarial CLI checks.
- Formal publication returned **200 OK** for
  [JingLan0v0/jmespath@0.1.3](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.3).
  Published archive SHA-256:
  `a9d92371caa70576b75500c15c44c6f134abef8be3d764ba0eb61ff79dc0f967`.
- A fresh consumer installed that exact version from Mooncakes, asserted
  `version() == "0.1.3"`, ran a normal query, and put the September unary input,
  255-level function input and shared-output expansion between valid requests.
  All three returned `limit_exceeded`; both valid results remained. It also
  round-tripped `stringify_bounded` output. Both debug and release printed:
  `published 0.1.3 query, parser/evaluator isolation, expansion guard and serialization OK`.

This final evidence record is a documentation-only follow-up to the published
source. The package's documents were captured before registry success; this
GitHub file contains the subsequent receipts. Final organizer acceptance and
any additional form submission are not established by these technical results.

## Historical 0.1.2 repair evidence (2026-10-19)

The September completion rejection reported a 4,001-character query consisting
of 4,000 `!` prefixes plus `@`. The old release overflowed the parser stack
before its post-parse depth check. A three-item batch produced no output and
exited 1 in debug and release builds. The organizer's report is the source for
that historical failure; it is not presented as a test of the new version.

The current parser checks recursion depth before descending and checks the
depth of each constructed AST node. `node scripts/verify.mjs` passes locally:
26 MoonBit tests, three end-to-end scenarios, debug and release CLI checks.
The CLI regression uses the exact 4,001-character expression between two valid
queries. The bad request returns `limit_exceeded`, while the two valid responses
remain present. Single-query mode exits 2 with no stdout. Separate tests cover
300 nested parentheses and the 256-node AST depth boundary. The PowerShell
pipeline and version smoke test also passes.

The Mooncakes 0.1.2 package passed archive extraction and package `moon check`
(66 existing compiler warnings, zero errors). The registry preflight returned
202 Accepted, and formal publication returned **200 OK**. A fresh, independent
module then ran `moon add JingLan0v0/jmespath@0.1.2` and called its public
`search_batch` API with the same three-item shape; the middle item returned
`limit_exceeded` and the process printed `published 0.1.2 batch isolation OK`.
Package URL: https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.2.

The pinned [official JMESPath compliance runner](conformance.md) could not
download its vectors on this machine during the local check because the GitHub
raw endpoint reset the connection. The pushed [GitHub Actions run
39249597919](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/39249597919)
completed successfully on source commit
`f569c4fcd3838c13e459d23893b8ede1822a163c`: both Windows and Ubuntu
passed the full verification and logged **892/892** official compliance cases.
The remote `main` file tree was verified identical to the locally tested tree,
and the 0.1.2 manifest was read back from GitHub. This record may be followed
by a documentation-only commit; the code and CI evidence remain tied to the
source commit above. Technical repair and publication do not imply that the
September organizer reopened or accepted the application.
