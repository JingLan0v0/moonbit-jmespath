# Project status and handoff

## Current state (2026-11-01)

### Latest audit: verification tooling (no new library release)

- Object keys/escaping: 531 cases plus duplicate JSON keys pass in both build
  modes and both output formats; retained as scripts/json-roundtrip.mjs.
- Fixed stale hardcoded report count (33 instead of actual 35), deriving counts
  from the harness. Failed new runs cannot leave an earlier success receipt.
- Full local verification passed; deliberate failure probe passed. CI pending.
- Runtime/API/version unchanged. Published library stays 0.1.14; no republish.

### Current release: 0.1.14

- Reject forged numeric repr in caller-constructed Json before evaluation or
  bounded serialization; preserve matching precision text and batch isolation.
- Reproduced the missing validation in both build modes. This is a direct library
  boundary issue, not a demonstrated CLI JSON injection.
- Local: 63 unit tests in both modes, 892 official cases per mode, 35 adverse/256
  mutations per mode, CLI, examples and PowerShell passed.
- Source fb53008 is on original main; Windows/Ubuntu CI 41305257961 passed.
  The 65-file archive passed inspection and fresh-extraction verification.
- Mooncakes returned 200 OK for 0.1.14. A new consumer downloaded the exact version
  and passed numeric representation, precision-text and batch checks plus retained
  regressions in both modes. See acceptance.md for hash and receipts.
- Current verified release: 0.1.14. Following docs-only commit records evidence;
  older entries are historical.

### Previous release: 0.1.13

- Fix inconsistent filter-opener syntax validation across root/postfix/nested
  contexts. Preserve literal content, valid whitespace and Unicode offsets.
- 30 invalid function calls showed no defect; retained them as CLI regressions
  alongside malformed filter batch isolation. Local: 60 units, 892 official cases
  per mode, 35 adverse/256 mutations per mode, examples and PowerShell passed.
- Source 7443279 is on original main; Windows/Ubuntu CI 41280805125 passed.
  The 65-file archive passed inspection and fresh-extraction verification.
- Mooncakes returned 200 OK for 0.1.13. A new consumer installed that exact
  release and passed filter syntax/literal behavior and retained regressions
  in both modes. See acceptance.md for receipts and archive hash.
- Current verified release: 0.1.13. Following docs-only commit records evidence;
  older entries are historical.

### Previous release: 0.1.12

- Fix compound expression reference precedence; valid map/ordering references
  with boolean, comparison and pipe operators now retain the whole expression.
- Added nested/delimiter/lazy-branch and budget/reuse regressions. Targeted local
  slice audit: 2,100 cases match Python slicing in each mode, no defect found.
- Local: 58 unit tests, 892 official cases per mode, 35 adverse/256 mutations
  per mode, examples and PowerShell passed.
- Source 1852abd is on original main. Windows/Ubuntu CI 41279980902 passed.
  The 65-file release archive passed inspection and fresh-extraction verification.
- Mooncakes returned 200 OK for 0.1.12. A new consumer downloaded that exact
  version and passed compound references and retained regressions in both modes.
- Current verified release is 0.1.12; see acceptance.md for receipts and hash.
  Following docs-only commit records evidence; older entries are historical.

### Previous release: 0.1.11

- Reproduced and fixed the 8-million-character string reversal heap abort.
- Meter string length without a character array; precharge reverse before output
  allocation and iterate Unicode backward without temporary character arrays.
- Local: 54 units, 892 official cases per mode, 35 adverse/256 mutation checks
  per mode, examples and PowerShell passed.
- Source 7a4a92c is on original main. Windows/Ubuntu CI 41279214295 passed.
  The 65-file archive passed inspection and fresh-extraction verification.
- Mooncakes returned 200 OK for 0.1.11. A fresh consumer downloaded the exact
  version and passed large-string guards, Unicode and retained regressions in
  debug/release. See acceptance.md for hash and receipts.
- Current verified version is 0.1.11. The following docs-only commit records
  receipts; older entries are historical. No final organizer acceptance claimed.

### Previous release: 0.1.10

- Meter all ordering scans/comparisons, including Unicode prefixes. Stable
  bottom-up merge sort propagates budget errors; input arrays stay unchanged.
- Local: 52 unit tests, 892 official cases per mode, 33 adverse/256 mutation
  checks per mode, examples and PowerShell. Independent sorting checks cover
  merge boundaries and ties. Larger sorts may now need a higher trusted budget.
- Source `e959381` is on main; Windows/Ubuntu CI 41161293727 passed. The 65-file
  archive passed inspection and fresh-extraction verification. Mooncakes returned
  200 OK; a new consumer installed exact 0.1.10 and passed all six ordering
  budget guards, ordinary sorting and retained regressions in both modes.
- Use 0.1.10 for current submissions. Acceptance.md records hash and links;
  following docs-only commit records receipts. Older entries are historical.

### Previous release: 0.1.9

- Reject non-finite intermediate scalar results before parent expressions can
  hide them. Lazy branches remain lazy and compiled queries recover on next call.
- Local checks: 49 units, 892 official cases per mode, 27 adverse/256 mutation
  checks per mode, examples and PowerShell passed. Numeric precision and avg
  running-sum overflow behavior are explicitly unchanged.
- Source `c12303a` is on main; Windows/Ubuntu CI 41038798979 passed. The 64-file
  archive passed inspection and fresh-extraction verification. Formal Mooncakes
  publication returned 200 OK; a new consumer installed exact 0.1.9 and passed
  overflow/lazy-branch plus retained regression checks in both modes.
- Use 0.1.9 for current submissions. See acceptance.md for hash and links. The
  following docs-only commit records receipts; previous records are historical.

### Previous release: 0.1.8

- Corrected UTF-16 ordering to JMESPath Unicode code-point order across all six
  sort/extreme functions. Iterator comparison avoids per-comparison char arrays.
- Local validation: 46 unit tests, 892 official cases per mode, all previous
  25/256 adverse tests per mode, examples and PowerShell passed. New vectors
  cover supplementary planes, prefixes, ties, normalization boundaries and numbers.
- Source `24b1231` is on main. Windows/Ubuntu CI 41036477186 passed; the 64-file
  archive passed inspection and fresh-extraction full verification. Mooncakes
  publication returned 200 OK. A new consumer installed exact 0.1.8 and passed
  all six ordering functions and retained safety regressions in both modes.
- Use 0.1.8 for current submissions. Acceptance.md records the archive hash and
  links; following docs-only commit records receipts. Earlier sections are historical.

### Previous release: 0.1.7

- CLI stream errors now exit 2 without unhandled exceptions. Diagnostic control
  characters are escaped to prevent multiline/terminal manipulation.
- Added five real-process CLI cases in both modes (read-only stdout, read-only
  stderr, both unavailable, closed pipe, hostile option). All local checks pass:
  43 unit tests, official 892/892 per mode, existing 25/256 adverse tests per mode,
  examples and PowerShell smoke. Details and limitations are in usage.md.
- Source `fe9cbc7` is on main; Windows/Ubuntu CI 41034982842 passed. The 64-file
  archive passed fresh-extraction verification. Mooncakes returned 200 OK for
  0.1.7; a new consumer passed API regressions and the downloaded CLI integration
  suite in both modes. Hash and links are in acceptance.md.
- Following docs-only commit records verified receipts. Earlier release notes
  below are historical. Use 0.1.7 for current submissions, retaining Git history.

### Previous release: 0.1.6

- Added constant-space JSON text preflight and public parse_json_bounded.
  Text search, CLI batch and expression JSON decoding share the guards.
- The known 12 MB escaped-string decoder crash is now a whole-transport error;
  excessive lexical tokens also fail before allocation. Existing 4.8 MB
  conversion batch isolation remains passing. No universal heap guarantee.
- Local checks: 43 unit tests, 25 adversarial/256 mutations per mode, 892 official
  cases per mode, API example, three scenarios and PowerShell smoke passed.
- Source `95be832` is on main; Windows/Ubuntu CI 40836861937 passed. Inspected
  64-file archive passed full verification after extraction. Formal Mooncakes
  publication returned 200 OK; a fresh consumer installed exact 0.1.6 and
  passed new API/guard and all retained regressions in both modes.
- See acceptance.md for archive hash and links. The following docs-only commit
  records observed receipts. Earlier version notes below are historical; their
  reported decoder case is addressed by 0.1.6, not a universal heap guarantee.

### 0.1.5 released

- Fixed allocation of arbitrary encoded JSON inside to_number; scalar scanning
  is now metered. Exact number grammar and whitespace compatibility retained.
- Local: 39 unit tests; 22 adversarial checks/256 mutations per mode; 892 official
  cases per mode; examples and PowerShell passed. The 4.8 MB conversion regression
  now preserves both neighboring batch results under the 192 MiB test heap.
- Separate remaining limitation: core transport decoding can exhaust constrained
  host memory before in-memory checks (12 MB escaped-string probe). Do not claim
  universal heap safety; resource-limits.md describes deployment boundaries.
- Source `a763059` is on existing main; CI 40834983084 passed both OS jobs.
  61-file extracted archive passed full verification. Mooncakes returned 200 OK
  for 0.1.5, and a fresh consumer passed conversion and historical regressions
  in both modes. See acceptance.md for the SHA-256 and links.
- At that checkpoint the submission version was 0.1.5. Following sections describe earlier
  releases; do not repeat publication of an existing version.

### Additional audit: 0.1.4 released

- Corrected null multi-select and null-left subexpression function semantics;
  preserved previous resource guards. Added three unit tests and both-mode CLI regressions.
- Added complete library example, batch file, API/error guide and contributor
  guide. Fixed quick-start paths and PowerShell invocation from another directory.
- Aligned the agent setup with the CI toolchain instead of downloading latest.
- Local checks passed: 37 unit tests, library example in both modes, three
  scenarios, CLI plus 20 adversarial/256 mutation checks per mode, 892 official
  cases in each mode, and PowerShell out-of-directory smoke.
- Source commit `bedcd49470e1e7c1e7c5ea80629c861beca7d6e2` is on main with
  original history intact. Windows/Ubuntu CI 40833672916 and pinned development
  setup 40833672917 passed. Both evidence artifacts were uploaded.
- On 2026-10-29 Mooncakes formal publication returned 200 OK for 0.1.4. The
  61-file archive passed a fresh-extraction verification; a new consumer installed
  exact 0.1.4 and passed null semantics and prior safety regressions in both modes.
  Archive hash and links are in acceptance.md. This evidence update is docs-only.
- No known failing checked case remains. This finite audit does not establish
  absolute correctness or organizer acceptance. That checkpoint used 0.1.4.

### Previous verified release: 0.1.3

- Project: MoonJMES, module `JingLan0v0/jmespath`.
- Repository: https://github.com/JingLan0v0/moonbit-jmespath . Continue on the existing main, preserving ordinary Git history for rollback.
- The participant supplied the organizer's October initial-review approval notice for this repository. Final acceptance/payment are still pending.
- Source version: 0.1.3. It preserves September's parser fix and additionally prevents the separately reproduced 255-level function evaluator crash, bounds expanded JSON and batch output, and uses iterative, work-budgeted equality.
- Local validation: 34/34 unit tests with warnings denied; three scenarios; debug/release CLI checks, each with 20 adversarial cases and 256 deterministic grammar mutations; official compliance 892/892 in each mode; PowerShell smoke.
- Source commit `7d84925484559cedd81121da75161dfe3e64f2c7` is on public main. Windows and Ubuntu CI passed: https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40682667445 . Both per-OS evidence artifacts were uploaded.
- Version 0.1.3 was published with registry 200 OK, after archive inspection and fresh-extraction verification. A new consumer installed the exact release and passed normal queries, three adverse batch items with valid neighbors, and bounded serialization in debug and release. Details and archive hash are in acceptance.md.
- Git transport timed out, so the existing authenticated GitHub API connection path uploaded the identical Git tree and commit, retaining its original parent. Local and remote source IDs match. The following evidence update changes documentation only.

## Durable entry points

- competition.md: current notice, requirements and organizer-only decisions.
- acceptance.md: separate local, CI and registry evidence; historical 0.1.2 evidence remains available.
- resource-limits.md: exact parser, execution, JSON and batch limits.
- publishing.md: preflight, archive review, publication and fresh install.
- architecture.md: pure MoonBit core versus Node CLI host boundaries.

## Continue after interruption

1. Check working tree and remote main without discarding user changes.
2. Do not repeat successful checks unless code/build inputs changed or a new concern warrants it. toolchain.json pins the compiler and Node version.
3. For code changes run `node scripts/verify.mjs`, compliance with and without `--release`, and PowerShell smoke. MOON_BIN may point to the local toolchain; set MOON_HOME to the same installation.
4. Push normal commits, verify the exact remote SHA and both CI jobs, and record their URLs. For a future release, follow publishing.md; all recorded releases are already published and must not be overwritten. A dry run is not publication, and a timeout requires checking the registry before retrying.
5. Install the exact published version in a new consumer project and exercise library batch isolation and bounded serialization. Update evidence only after observing the result. Do not guarantee organizer acceptance.
