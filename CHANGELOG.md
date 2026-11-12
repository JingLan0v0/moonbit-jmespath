# Changelog

## Unreleased - quick start and checked demos

- Organize the English and Chinese READMEs around installation, working
  examples, resource limits and verification.
- Add a CLI demo with asserted results for three scenarios, a per-request
  resource error and invalid outer JSON. Run the demo in both CI build modes.

## 0.1.20 - function error locations

- Report the function-name offset for type, arity and unknown-function errors.
  Resource errors raised during a function can report that call's location.
- Preserve inner function locations and continue using zero-based Unicode
  scalar offsets across the library and CLI.

## 0.1.19 - batch compilation reuse

- Reuse one short, successfully compiled expression within a batch. Each
  request still validates its input and has its own work budget and literal
  copies.
- Cover work-limit recovery, mutable literal isolation, and requests whose
  expressions exceed the reuse slot's size limit.

## Unreleased - performance benchmarks

- Add reproducible JS benchmarks for compilation, compiled search, sorting,
  long strings, serialization, batch queries and full CLI startup.
- Record fixed workload sizes, raw timing samples, build mode, source revision,
  host and toolchain, and peak RSS for library cases.

## 0.1.18 - isolate compiled JSON literals (2026-11-12)

- Keep mutable array and object literals private to each search, including
  nested collections returned through a projection or function.
- Copy each evaluated container literal at most once per search, with copy work
  charged to `max_steps`. Document when results can share caller input.
- Cover mutations of returned values, input revalidation, failure recovery and
  the existing JSON depth limit through the public API.

## Unreleased - unified verification (2026-11-12)

- Use one verification command locally and in CI for strict checks, both JS
  build modes, examples, official conformance and Windows PowerShell smoke.
- Reuse each mode's CLI for conformance and record source, toolchain, counts
  and per-step status in a report that survives early failure.

## Unreleased - MoonBit toolchain compatibility (2026-11-12)

- Update source declarations and generated interfaces for MoonBit
  `0.10.20+65efd5b93`, including the current trait derivation and integer syntax.
- Pin Windows and Ubuntu CI to the same release, record `moon version --all`
  as a CI artifact, and run strict release tests on the JS backend.
- Select the matching local toolchain in the PowerShell wrapper and document the
  compiler requirements for building GitHub main.

## Unreleased - bounded failure reduction (2026-11-11)

- Add a separate reducer for saved equality/composition failures, with attempt
  and time limits, repeat confirmation, stable failure categories and replay output.
- Recompute expectations when supported JSON inputs shrink; preserve expression
  text and opaque fixtures, including requests needed to reproduce batch failures.
- Extract the composition corpus/oracles without changing its fingerprint, and
  retain reducer unit/integration checks plus an injected-defect regression fixture.
- Test tooling only; runtime and published package remain 0.1.17.

## Unreleased - composition verification (2026-11-11)

- Retain a bounded seeded expression generator with independent expected values:
  8,192 combinations plus 15 normative cases in each build mode.
- Check category counts and corpus fingerprints across modes, save replayable
  failures, and include them in CI artifacts. Explicitly assert known reference
  deviations instead of treating a third-party evaluator as an absolute oracle.
- Test tooling only; library and published package remain 0.1.17.

## Unreleased - equality verification (2026-11-11)

- Retain deterministic deep equality, key-order, type distinction and contains
  checks in a standalone Node harness, integrated into both verification modes.
- Record actual query counts; save replayable semantic/process failures and
  upload them with CI evidence. Clear stale receipts on a new run.
- Test tooling only; library and published package remain 0.1.17.

## Documentation audit - 2026-11-10

- Correct stale current-release links and verification counts in both READMEs.
- Record a fresh local verification and 60,384 function/composition comparisons
  per build mode, including reviewed Python reference differences.
- No runtime change or new registry release; published version stays 0.1.17.

## 0.1.17 - 2026-11-06

- Keep projection lexical scope separate from AST shape, so a suffix following
  a parenthesized projection applies to its complete result.
- Respect unary negation binding relative to dot, flatten, filters and indexes,
  while preserving suffixes owned by an active projection.
- Add fixed API examples, compiled-query resource/reuse regressions and 288 CLI
  grouping/precedence cases per build mode. No new evaluator frames or public API.

## 0.1.16 - 2026-11-06

- Tokenize contiguous `[]` as the flatten operator. Reject whitespace-separated
  empty brackets at compile time, including root, postfix, references, filters,
  groups and skipped boolean branches, per the JMESPath bracket-specifier grammar.
- Preserve whitespace around flatten, nonempty brackets and literal bracket text.
- Add lexer/public API regressions and 45 real-process batch-isolation cases in
  each build mode. Parser depth and evaluation/output budgets remain enforced.

## 0.1.15 - 2026-11-04

Reject misplaced expression references during compilation, including in lazy branches, lists and filters. Direct reference arguments continue to support pipes, boolean expressions, grouping inside the reference and nested function calls.

## Unreleased - verification target isolation (2026-11-03)

- explicitly bind every full-verification CLI harness to the debug/release
  artifact built by that run, preventing inherited JMES_CLI_PATH redirection
- record relative CLI artifact paths in the verification receipt
- exercise an intentionally unusable inherited CLI path in both CI jobs;
  standalone harness overrides remain available for testing published packages
- no runtime/API/version change; published library remains 0.1.14


## Unreleased - verification tooling (2026-11-01)

- derive report boundary/mutation counts from actual adversarial harness output;
  remove the stale hardcoded count of 33 when 35 checks were being executed
- remove a previous success summary before starting verification, so a failed
  new run cannot leave a stale passed receipt; reject missing/mismatched counts
- add object-key/escaping roundtrip checks in debug/release and compact/pretty
  output, including prototype-like keys, duplicate keys and Unicode/control text
- no runtime/API change; published library version remains 0.1.14


## 0.1.14 - 2026-11-01

- validate caller-supplied Json numeric repr before evaluation and serialization;
  malformed/non-numeric/mismatched representations now return invalid_value
- check the output-size budget before validation and reject non-number alphabet
  before parsing, avoiding construction of arbitrary encoded arrays or objects
- preserve matching numeric spelling, including large-integer precision text;
  equality is based on the stored binary64 value, not new exact arithmetic
- test serialization, nested input rejection, compiled reuse and batch isolation
- this affects programmatically constructed Json values; it is not a demonstrated
  raw-JSON CLI input injection


## 0.1.13 - 2026-11-01

- consistently reject whitespace inside the [?-filter opener at the lexer
  boundary, including root, grouped and expression-reference contexts
- remove the postfix-only duplicate check; keep Unicode diagnostic offsets,
  valid surrounding whitespace and quoted literal content unchanged
- add mixed-batch regressions for malformed filter markers and 30 invalid
  function calls with exact error categories and surviving valid neighbors
- this tightens acceptance of malformed syntax; it is not a crash or new feature


## 0.1.12 - 2026-11-01

- parse complete expression references, including comparison, boolean and pipe
  operators, instead of binding & as tightly as unary negation
- fix valid map/sort_by/min_by/max_by calls incorrectly returning invalid_type
  for fallback keys, comparison mappings and piped transformations
- test nested references, argument delimiters, lazy branches, budget exhaustion
  and compiled-query recovery; retain parser/evaluator depth guards


## 0.1.11 - 2026-11-01

- fix a reproduced process-wide heap abort on an 8,000,000-character reverse
  inside a batch: precharge UTF-16 copy work before allocating the result
- build reversed strings from reverse Unicode iteration without character arrays;
  count string length through a metered iterator with constant extra space
- add constrained-process isolation, Unicode and compiled-query recovery tests
- string length/reverse can now reject large valid inputs with limit_exceeded;
  raising budgets explicitly trades protection for accepted workload size


All notable changes to MoonJMES are recorded here.

## 0.1.10 - 2026-10-31

- meter ordering type scans, comparisons, Unicode iterator advances, sorting
  copies and merge writes against max_steps across all six ordering functions
- use stable bottom-up merge sort so budget errors stop sorting immediately;
  the pinned core sort comparator cannot raise an error
- add long-common-prefix isolation tests, low-budget rejection, recovery and
  unchanged-input tests; compare merge boundaries/ties against independent sorting
- large legitimate sorts can now exhaust the default budget; this is an
  intentional resource-contract tightening, not a wall-clock timeout

## 0.1.9 - 2026-10-30

- reject non-finite scalar results at evaluated expression boundaries, before
  parent functions/comparisons can hide arithmetic or numeric-conversion overflow
- preserve lazy boolean branches and query reuse after an overflow error
- add unit regressions for type/comparison/collection/boolean wrappers and two
  isolated CLI batch cases with successful neighboring requests in both modes
- this tightens the existing finite-JSON policy; IEEE binary64 arithmetic and
  rounding are unchanged, including rejection when avg's running sum overflows

## 0.1.8 - 2026-10-30

- compare string ordering by Unicode code points instead of UTF-16 code units,
  fixing supplementary-plane ordering in sort/min/max and their _by variants
- use character iterators rather than allocating arrays for every comparison
- add regressions for BMP/supplementary boundaries, U+10FFFF, prefixes, empty
  strings, combining sequences, equal-key order and numeric extremes
- no locale collation or Unicode normalization is introduced

## 0.1.7 - 2026-10-30

- handle stdout/stderr stream errors, including closed downstream pipes, with
  exit 2 instead of an unhandled Node exception and internal stack trace
- preserve output-error status if the main query itself succeeds; stderr failure
  cannot recursively fail the stdout diagnostic fallback
- escape control, line-separator and bidi-format characters in CLI diagnostics
  to prevent terminal controls and forged diagnostic lines; JSON stdout is unchanged
- add both-mode real-process checks for read-only descriptors, both streams
  unavailable, a closed output pipe and hostile option text

## 0.1.6 - 2026-10-29

- preflight JSON text before decoder allocation: 8 Mi source units per string
  token, 1,000,000 lexical tokens including duplicate keys, and nesting 1,024
- share public parse_json_bounded across text search, batch CLI and expression
  literals/quoted identifiers; preserve syntax categories and per-item checks
- close the reproduced 12 MB escaped-string decoding failure from 0.1.5 with
  explicit whole-transport errors; also reject excessive object allocation
- test inclusive boundaries, escaped punctuation, malformed JSON, duplicate
  keys and three new constrained-heap transport regressions in both modes
- these are additional input restrictions, not a fixed peak-memory guarantee

## 0.1.5 - 2026-10-29

- reject non-numeric string contents before `to_number` invokes the JSON parser,
  avoiding construction of discarded arrays/objects; exact numeric syntax is
  still validated by the parser, retaining existing whitespace compatibility
- charge numeric-string scanning to the per-query work budget
- add numeric grammar/budget tests and isolated 4.8 MB encoded-object regression
  with valid neighboring requests in both CLI modes under the 192 MiB test heap
- document that the input byte cap is not a peak-memory guarantee for decoding

## 0.1.4 - 2026-10-28

- preserve null inputs in multi-select lists/hashes, including projections and map
- evaluate subexpression functions on null left results, allowing fallbacks and
  propagating type errors instead of silently returning null
- add three semantic unit tests and debug/release CLI regressions beyond the
  pinned official suite; keep parser/evaluator/output guard regressions
- provide a runnable public API example, committed batch input, accurate exit
  and diagnostic contracts, and contributor instructions
- fix quick-start file paths and make PowerShell scenarios independent of the
  caller's directory; verify both example modes and out-of-tree invocation
- align the development-agent setup with CI's pinned MoonBit and Node versions

## 0.1.3 - 2026-10-28

- prevent the reproduced debug evaluator overflow from 255 nested `to_array`
  calls with an execution depth guard independent from AST depth
- bound expanded JSON output, pretty formatting, batch envelopes and aggregate
  batch successes before serialization
- replace recursive JSON equality with iterative, work-budgeted traversal
- check `join` size and object result budgets before allocation/insertion;
  meter reductions and reject non-finite output
- count expression characters before allocating the lexer array and classify
  JSON nesting exhaustion as a resource error
- add public `stringify_bounded`, 20 adversarial subprocess checks and 256
  deterministic grammar mutations in each debug/release run
- clear existing compiler warnings, enforce exact official error categories
  in both modes, add a pinned GitHub API fallback and CI evidence artifacts

## 0.1.2 - 2026-10-19

- validate configurable resource limits and reject excessive parser nesting before recursion grows unchecked
- prevent integer overflow in index parsing and large-stride slices
- enforce result limits before building projected and function-produced arrays,
  and bound CLI reads to 16 MiB
- accept a UTF-8 BOM, report malformed batch JSON clearly, and isolate malformed batch entries
- add real CLI integration checks and clarify the public API and usage examples
- reproduce the September rejection's 4,001-character unary expression in
  three-request batch and single-query modes, in both debug and release CLI
  builds; verify errors do not discard the adjacent successful requests
- test the exact allowed AST depth boundary and a deeply grouped expression

## 0.1.1 - 2026-09-24

- add a complete Simplified Chinese README and installation guide
- add a PowerShell entry point that uses the repository-local MoonBit toolchain
- document the verified GitHub, Mooncakes, CI, and conformance evidence

## 0.1.0 - 2026-09-24

- implement the JMESPath lexer, parser, immutable AST, and bounded evaluator
- implement the standard JMESPath function set and expression references
- expose compiled, one-shot, JSON-text, and isolated batch APIs
- provide a file/stdin CLI, three runnable scenarios, tests, and cross-platform CI
- pass all 892 cases in the pinned official JMESPath compliance suite
