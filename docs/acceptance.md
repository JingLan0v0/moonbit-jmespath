# MoonJMES acceptance evidence

## Committed composition harness (2026-11-11)

Seed `0x20261111` constructs 512 depth-bounded expression trees (472 unique
expressions), each evaluated on 16 datasets, plus 15 normative fixtures. All
8,207 queries passed in each mode. The 14 generator categories include grouping,
negation, functions, Boolean expressions, pipes, projections, indexing, filters,
map references and flattening. Expected values are calculated by independent
closures, without parsing generated text or invoking a reference evaluator.
The controlled grammar supplements, rather than replaces, official compliance.
Both modes produced corpus SHA-256
`e7124f3752d663692fb5111742f09910a0c00999e54f78c4416f73ce71abf4d4`.

Explicit fixtures check previously reviewed reference deviations in nonnumeric
ordering, Boolean/number contains and merge argument types. They also distinguish
map from projection null handling, grouped from ungrouped projection indexing,
and a failing map request from its healthy batch neighbor. See CONTRIBUTING.md
for specification references, bounded execution and replay commands.

An isolated incorrect-output CLI produced exit 1 and a single replayable case.
A nonexistent CLI captured the attempted 250-request batch; the real CLI replayed
both successfully from outside the repository. A deliberately wrong error code
was rejected; the saved expected-error case replayed successfully. Invalid replay
JSON replaced the previous success report with a setup failure while preserving
the original input. No automatic minimization is implemented.

Full local verification, 70 unit tests per mode, official 892/892 cases per mode
and PowerShell smoke passed. Existing equality, boundary, grammar mutation,
grouping, serialization, API and scenario checks remained green. The initial
official-suite download was blocked by DNS in the restricted environment; the
network-enabled retry passed. Source `88b6e0b09aed6eda69f944dd14f9d0bfddacfea2`
passed Windows and Ubuntu CI from clean checkouts:
[run 43001037541](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/43001037541).
The following documentation-only commit records these source receipts.
This changes test tooling/docs only: runtime and published package remain 0.1.17,
with no new registry publication or fresh-consumer receipt claimed.

## Committed equality harness (2026-11-11)

Promoted the independent canonical-JSON equality audit into a standalone Node
script. Full verification pins its debug/release artifacts and checks actual
pair/query counts agree. Each mode passed 4,125 pairs and 20,625 queries covering
type distinctions, object key order, nested structures, Unicode and contains.
No Python dependency or ignored local audit fixture is required.

An isolated fake CLI returning incorrect values produced exit 1, a failed report
and one replayable case. The real CLI replay passed when invoked outside the
repository. A missing CLI then replaced that successful receipt with failure and
preserved the attempted batch. CI now uploads saved cases with summaries.

Full local verification and release unit tests passed (70 units per mode), as
did official 892/892 cases in both modes, 80 boundary/256 mutation checks per
mode, grouping/escaping checks, API examples, scenarios and PowerShell. CI is
passed on Windows and Ubuntu for source `8e0510480d19ceb7dae2a2cff502cc041fd83bbf`:
[run 42963695185](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/42963695185).
Clean checkouts ran the committed harness without local audit caches. The following
documentation-only commit records these source receipts. This is test tooling only; there is no new
Mooncakes publication or fresh-consumer claim. Published runtime stays 0.1.17.

## Follow-up function/composition audit (2026-11-10)

Rechecked local and remote main at `7ac06e10c25fa7c3899896414e24e3d3440e5436`;
the working tree was initially clean and the runtime remains 0.1.17.
This round actually ran full verification, release unit tests, both official
conformance modes and PowerShell smoke: 70 units per mode, 892 official cases
per mode, 80 boundary checks and 256 mutations per mode, 288 grouping cases,
531 key/escape cases in each output format, API examples and all three scenarios.
Initial restricted-network conformance failed; the authorized network retry
passed. These are new local results, not reused release/CI receipts.

A new seeded function/composition probe (seed 20261110, depth 5, 16 datasets)
executed 60,384 expression/data pairs in each mode against jmespath.py 1.0.1.
Both modes produced the same 15 differences, all reviewed against the
[specification](https://jmespath.org/specification.html):

- Seven cases: Python permits string ordering or raises a host TypeError for
  number/string ordering. The specification's ordering operators apply only to
  numbers; MoonJMES correctly returns null for other types.
- Three cases: Python merge accepts a later array argument through dict.update;
  MoonJMES correctly requires objects and reports invalid_type.
- Five cases: Python contains treats true as numeric 1; MoonJMES correctly
  distinguishes JSON booleans from numbers.

No new runtime defect was established within this coverage. This is not a claim
of zero bugs or exact equivalence to Python. Comparisons cover successful values
and success/failure status, not equal error categories or offsets.
The ignored local script/report are `_build/function-composition-20261110.py`
and `.json`; the fresh reference dependency is `_build/reference-python-20261110`.
Script SHA-256: `0a017c194c770c24d6211ef2c7204011108038230bc24e3139c32341181c8501`.
The original reference cache was unreadable, so a fresh exact 1.0.1 was installed.

Corrected both READMEs' stale current-version link (0.1.10 to 0.1.17) and stale
52/33 test counts (70/80). This is a documentation-only update, with no package
publication or fresh-consumer claim for this round. Historical publication and
consumer evidence remains in the 0.1.17 section below. CI for this documentation
commit must be checked separately; historical CI is not its receipt.

## 0.1.17 projection scope and unary precedence (2026-11-06)

Both 0.1.16 build modes returned `[]` for `(a[*])[0]` on
`{"a":[{"b":1},{"b":2}]}`, rather than the first object. `(a[*]).b` also kept
projecting and returned `[1,2]` instead of null. Separately, unary negation
incorrectly absorbed dot, flatten and filter suffixes, so `!a.b` returned true
instead of null. Parentheses now close lexical projection scope; operator binding
matches the [upstream parser](https://github.com/jmespath/jmespath.py/blob/1.0.1/jmespath/parser.py).
No runtime grouping node or extra evaluator frame is introduced.

A seeded local composition audit compared 13,560 valid-expression/data pairs per
mode with jmespath.py 1.0.1, checking successful values and success/error outcomes,
and found no differences after repair. It does not claim exhaustive equivalence
or identical diagnostics. The reference is an ignored test dependency.
Committed regressions include 288 CLI examples per mode, fixed public API cases,
and custom step/result-limit checks with compiled-query reuse after failure.

Local debug/release each passed 70 unit tests, 892 pinned official cases,
80 boundary/isolation checks, 256 mutations, JSON roundtrips, API examples and
scenarios. PowerShell smoke passed.

Source commit `ca9f7fd2cdd471842a70fba32b9d970400180a45` is synchronized to original
main with parent history preserved. [CI 42175190843](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/42175190843)
passed on Windows and Ubuntu. This evidence applies to the source commit;
the following documentation-only commit records the receipts.

The 66-entry archive excluded credentials, Git data, builds, caches, toolchains
and the Python reference. Its independent extraction passed the full verifier.
SHA-256 `4b8bca24abebc3bea6393ea0d68ee107eec33cbb8ef753de947683e5aa3f3511`.
Mooncakes preflight returned 202 success and formal publication returned 200 OK.
A fresh consumer downloaded exact 0.1.17 and passed grouping, negation,
limit/reuse checks and retained regressions in both modes. An initial consumer
test compile warning was corrected by parsing input outside its narrow error
catch; no package change was needed.
[Mooncakes 0.1.17](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.17).

## 0.1.16 atomic flatten operator (2026-11-06)

Version 0.1.15 reproducibly accepted `[ ]`, `@[ ]`, tab/newline-separated
brackets, nested references and skipped branches in both debug and release.
The [bracket-specifier grammar](https://jmespath.org/specification.html#grammar)
defines contiguous `[]`. The lexer now emits an atomic flatten token, preserving
valid projection semantics and rejecting split operators before evaluation.

Local debug and release each passed 67 unit tests, all 892 pinned official cases,
80 boundary/isolation checks and 256 grammar mutations. The 45 added isolation
checks combine five whitespace forms with nine expression contexts, each between
two valid requests. JSON roundtrips, public API examples, three scenarios and the
PowerShell wrapper passed.

Source commit `63f5a2ee35221c0d7f9463a6e5956c50590e6b5d` is on the original main
branch, preserving its parent history. [CI 42173155305](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/42173155305)
passed on Windows and Ubuntu. The following documentation-only commit records
these receipts; the linked CI result is for the source commit above.

The 66-entry archive excluded credentials, Git data, caches, toolchains and build
outputs. Fresh extraction passed the complete verifier. Archive SHA-256 is
`832b8859b671570f9bed8ba21fe4a87055b8ea5a8bfe458d92e8adf4fa89ebc1`.
Mooncakes dry-run returned 202 success and formal publication returned 200 OK.
After refreshing the registry index, a new consumer downloaded exact version
0.1.16 and passed split-operator rejection, valid flatten, batch isolation and
all retained release regressions in debug and release.
[Mooncakes 0.1.16](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.16).

## 0.1.15 reference placement (2026-11-04)

In debug and release, 0.1.14 accepted misplaced references inside skipped boolean branches, a list on null and a filter on an empty array. The [JMESPath grammar](https://jmespath.org/specification.html#grammar) permits expression-type as a function argument. The parser now checks placement during compilation. Regressions verify syntax offsets and distinguish a misplaced reference from a valid argument passed to a function requiring another type.

For source 8f9e01b60ab05b94b1b0d9a4e7c3107012a05fa7, debug and release each passed 64 unit tests, 892 official cases and 35 boundary checks. The four formerly accepted queries returned per-item syntax errors alongside a successful map result. PowerShell and all three scenarios passed. [Windows and Ubuntu CI](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41781749044).

The 66-entry archive passed independent extraction and verification (SHA-256 d9027381d2724239c0c3423e8b8ccca6ebbbd62277390a73ce2877d3a8701498). Mooncakes returned 200 OK. A fresh consumer downloaded exact version 0.1.15, checked compile-time rejection and valid map behavior, and passed the retained regressions in both modes. [Mooncakes 0.1.15](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.15).

## Verification target and CLI boundary audit (2026-11-03)

A local audit of 11 invalid CLI/I/O forms and three valid stdin/BOM forms passed
in debug and release: duplicate/unknown options, extra arguments, option terminator,
empty input, repeated BOM, wrong batch root and missing files behaved as expected.
No runtime defect was found in those cases.

Reproduced a verifier defect by setting JMES_CLI_PATH to a nonexistent script:
the full verifier built its own CLI but the debug integration harness inherited
the external target and failed. Release harnesses already selected their build.
The full verifier now supplies both target paths explicitly, records their relative
paths, and requires an explicit environment when invoking the adversarial harness.
Standalone harness overrides are retained for downloaded-package testing.

CI now injects an intentionally unusable inherited path during Verify project,
so both OS jobs exercise this regression. Local full verification passed with
that unusable path still present: 63 units, 35 adversarial/256 mutation checks
per mode, JSON roundtrips and scenarios. The receipt records the expected debug
and release paths. Official 892/892 cases per mode and PowerShell smoke passed.
Source 21e44d575efb4d056ff7173cf9ebafe82289a6fe is on original main with
history retained. [CI 41655347262](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41655347262)
passed on Windows and Ubuntu, including the injected-path regression and both
conformance modes. The following documentation-only commit records the receipt.
No library version or runtime changes; no Mooncakes republish is required.


## Post-0.1.14 object/escaping and report audit (2026-11-01)

No new runtime defect was found in 531 key/escaping cases plus a duplicate JSON
key case, each run in debug/release and compact/pretty output. The new
scripts/json-roundtrip.mjs retains these checks in the standard verification
pipeline. Cases include __proto__, constructor, quoted keys, U+0000..U+00FF keys,
Unicode, merging and duplicate multi-select keys. Comparisons use independent
Node objects and JSON parsing; they do not require an object-key output order.

Found and fixed a verification defect: the machine-readable summary hardcoded
33 adversarial checks although the harness executed 35. Counts now come from a
structured harness result, with integer validation and debug/release agreement.
A new run removes the previous success receipt before testing. An isolated probe
seeded a passed receipt, deliberately used a missing compiler, and confirmed the
failed run left no previous successful summary.

Local full verification passed: 63 unit tests, examples, CLI, 35 boundary checks
and 256 mutations per mode. The report now records 35 and 256. No production
MoonBit code or module version changed; Mooncakes 0.1.14 remains the verified
library release. These new verification scripts are GitHub changes only.
Source 054deec6a75100e072b3ea3a02b26259a62fefd1 is on original main with
history retained. [CI 41305826247](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41305826247)
passed on Windows and Ubuntu, including both official conformance modes. The
following documentation-only commit records that receipt. No registry publish
was performed for this test-tooling-only change.


## 0.1.14 numeric representation audit (2026-11-01)

Core Json::number accepts a caller-supplied repr, and its serializer writes that
text verbatim. The 0.1.13 size walker checked only the Double and repr length.
A regression expecting invalid_value for Json::number(1.0, repr="null") failed
in both debug and release: bounded serialization accepted the forged value.
Other malformed text could change serialized structure or disagree with queries.

Validation now checks size first, scans a numeric-only alphabet before parsing,
and requires a number equal to the finite stored Double. This applies through
the shared input/output shape validator and preserves matching large-integer
repr. Equality remains binary64, including its precision limitations. Surrounding
whitespace is rejected in a manually supplied repr; parsed JSON remains supported.
The demonstrated boundary is direct library construction, not ordinary CLI input.

Tests cover malformed/mismatched representations, valid large-number notation,
query reuse, nested data and valid batch neighbors. Local verification passed:
63 unit tests in both debug and release; 892 official cases per mode; 35 adverse
checks/256 mutations per mode; CLI, API/scenario examples and PowerShell smoke.
Verified release evidence (2026-11-01):

- Source fb530083e8ec1057b1eb6ca19a7751f9b9123eb5 is on original main,
  preserving history. [CI 41305257961](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41305257961)
  passed Windows and Ubuntu. Local release-mode unit tests were also run explicitly.
- The 65-file archive excludes credentials, Git, build and cache content and
  passed full verification after fresh extraction. SHA-256:
  7d1a1fa85a106d522fc058af51fdd4fab4e9c6053160f2b4ac04b6dbadcaab7f.
- Preflight returned 202 dry-run success; formal publication returned 200 OK.
- A fresh consumer downloaded exact JingLan0v0/jmespath@0.1.14 and passed forged
  numeric repr rejection, large-integer spelling preservation, batch isolation
  and retained regressions in debug/release.
- [Mooncakes 0.1.14](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.14).
  The following docs-only commit records receipts. Organizer final acceptance
  remains separate from technical verification.


## 0.1.13 filter syntax and error audit (2026-11-01)

In 0.1.12, [ ?@], tab-separated markers, grouped filters and map(&[ ?@], @)
incorrectly succeeded; @[ ?@] correctly failed. Reproduced in both build modes.
The [official grammar](https://jmespath.org/specification.html#filter-expressions)
defines the adjacent opener [?. Validation now occurs in the lexer everywhere,
replacing a postfix-only check. This is a malformed-syntax consistency repair,
not a crash finding. Valid whitespace outside the opener and literal text remain
unchanged; Unicode-scalar diagnostic offsets are tested.

The function audit found no new defect in 30 wrong-arity/type/unknown-function
cases. Those checks are now retained in both-mode CLI integration, with exact
error categories and valid neighbors. Eight malformed filter cases have the same
batch isolation checks, plus unit coverage for four whitespace characters and
nested/reference contexts.

Local checks passed: 60 unit tests; 892 official cases per mode; 35 adversarial
checks and 256 mutations per mode; complete API/scenario examples and PowerShell.
Verified release evidence (2026-11-01):

- Source 74432793ff989ccfabb4c66f075c477df56fd3e7 is on original main,
  preserving commit history. [CI 41280805125](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41280805125)
  passed on Windows and Ubuntu.
- The 65-file archive excludes credentials, Git, build and cache content and
  passed full verification after fresh extraction. SHA-256:
  d2ffaa3d32489af32a2c02206586bef878f4a75dc29dd399c8b196ef07ebb95a.
- Preflight returned 202 dry-run success; formal publication returned 200 OK.
- A new consumer downloaded exact JingLan0v0/jmespath@0.1.13 and passed split
  marker rejection, valid whitespace, unchanged literal content and retained
  regression checks in debug/release.
- [Mooncakes 0.1.13](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.13).
  The following docs-only commit records receipts. This is engineering evidence,
  not organizer final acceptance.


## 0.1.12 expression-reference audit (2026-11-01)

In 0.1.11, valid map calls with fallback, comparison or pipe expressions and
sort_by with fallback keys returned invalid_type in debug and release. The
parser used unary precedence after &, leaving operators outside the reference.
The [official grammar](https://jmespath.org/specification.html#grammar) defines
expression-type as & followed by an expression. Parsing now consumes all its
operators until the argument delimiter. Nested references, short-circuiting,
ordering ties and work-budget recovery have explicit regressions.

The adjacent slice audit compared 2,100 combinations of start/stop/stride and
empty/singleton/four-element inputs against Python slicing, including signed
32-bit extremes; all matched in both modes. This was a targeted local probe,
not an expansion of the pinned official 892-case suite.

Local verification passed: 58 unit tests; 892/892 official cases per mode;
35 adversarial/256 mutation checks per mode; complete API and scenario examples;
PowerShell smoke. Eight additional CLI cases cover compound references in both
modes.

Verified release evidence (2026-11-01):

- Source 1852abd46f157fbf0ca85e40c0e037dff54ca4c9 is on original main with
  normal rollback history. [CI 41279980902](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41279980902)
  passed on Windows and Ubuntu.
- The 65-file archive excludes credentials, Git, build and cache content; a
  fresh extraction passed full verification. SHA-256:
  8e65e2027662d391aeddd84b73dc683735509af79a23ba2d713345d0ce806507.
- Dry-run returned 202 success; formal registry publication returned 200 OK.
- A new consumer downloaded exact JingLan0v0/jmespath@0.1.12 and passed fallback,
  comparison, pipe and sorting references plus all retained safety checks in
  debug and release.
- [Mooncakes 0.1.12](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.12).
  The next documentation-only commit records receipts. Organizer acceptance
  remains separate from these engineering checks.


## 0.1.11 string allocation audit (2026-11-01)

Reproduced in 0.1.10: a decoded batch with an 8,000,000-character string queried
by length(reverse(@)) exits 134 with empty stdout in debug and release under
192 MiB old-space. Both valid neighboring requests are lost. length(@) alone
succeeds but needlessly allocates a character array and bypasses the work budget.
The fix precharges reverse output work and removes both operations' character
arrays. Tests retain Unicode scalar behavior, query reuse and batch isolation.

Local verification passed: 54 unit tests, 892/892 official cases per mode,
35 adversarial checks and 256 mutations per mode, API/scenario examples and
PowerShell smoke. The former crashing batch now retains both neighbors and
returns limit_exceeded for the large string request.
Verified release evidence (2026-11-01):

- Source 7a4a92c94afcb432b0f0bc58ff16210eafc775ae is on the original main,
  preserving history. [CI 41279214295](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41279214295)
  passed on Windows and Ubuntu.
- The 65-file archive contains no credential, Git, build or cache content and
  passed full verification after fresh extraction. SHA-256:
  99e092fda7eb43091a3991838751fdd62558aef8d4501fb1c13d8b8c21e3f2ff.
- Preflight returned 202 dry-run success; formal publication returned 200 OK.
- A new consumer downloaded exact JingLan0v0/jmespath@0.1.11 from the registry
  and passed large-string rejection, Unicode behavior and all retained parser,
  evaluator, decoding, ordering, overflow and serialization checks in both modes.
- [Mooncakes 0.1.11](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.11).
  This following documentation-only commit records receipts. Finite engineering
  checks do not constitute organizer final acceptance or a universal heap bound.


## 0.1.10 ordering work-budget audit (2026-10-31)

In 0.1.9, 32 strings with 40,000-character common prefixes completed sort/min/max
despite comparison work exceeding the default logical budget. Ordering scans and
comparisons were previously unmetered. All six ordering functions now consume
the budget, and stable merge sorting can raise and stop immediately.

Local verification: 52 unit tests; official suite 892/892 per mode; 33 adversarial
checks and 256 mutations per mode; examples and PowerShell smoke. Each ordering
function rejects the prefix workload without losing neighboring requests.
Additional CLI checks compare numeric sorting and stable ties at lengths
0/1/2/3/31/32/33/257 with Node's independent sort in debug and release. Tests
cover input preservation and query reuse after exhaustion.

Verified release evidence (2026-10-31):

- Source `e959381573096a8034ed177065aa12e8260525e7` is on original main, with
  prior history preserved. [CI 41161293727](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41161293727)
  passed on Windows and Ubuntu.
- 65-file archive inspected without credentials/build/cache content and fully
  verified after fresh extraction. SHA-256:
  `20d48c4645a562da0750ae7dcd394933becd8a01093333fb161c8b15cf858e02`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
- A fresh consumer installed exact `JingLan0v0/jmespath@0.1.10` and passed
  budget exhaustion for all six ordering functions, ordinary sorting and all
  retained consumer regressions in debug and release.
- [Mooncakes 0.1.10](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.10).
  Following docs-only commit records receipts. Organizer final acceptance is
  still a separate decision.

## 0.1.9 intermediate numeric-value audit (2026-10-30)

Reproduced in 0.1.8: direct sum overflow returned invalid_value, while wrapping
it in type(), a comparison or collection-length pipeline incorrectly succeeded.
Overflowing to_number strings could also be hidden. Scalar results are now
validated before returning to the parent expression, consistent with the
project's finite-JSON policy. This is a representation guard, not higher-precision
arithmetic or an overflow-free averaging algorithm.

Local validation: 49 unit tests; 892/892 official cases per mode; 27 adverse
checks and 256 grammar mutations per mode; API example, scenarios and PowerShell.
New regressions cover hidden overflow, short-circuit branches, compiled reuse
and batches with normal neighbors.

Verified release evidence (2026-10-30):

- Source `c12303afaa0be1a19aed5c60b65a3c4c04c36bb5` is on public main,
  retaining prior history. [CI 41038798979](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41038798979)
  passed on Windows and Ubuntu.
- 64-file archive inspected without credentials/build/cache content and fully
  verified after fresh extraction. SHA-256:
  `1e020844ffdc99af7033f4a55ae572ec66c72fedf3923750b909a866be881f1d`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
- A fresh consumer installed exact `JingLan0v0/jmespath@0.1.9` and passed
  hidden arithmetic/conversion overflow, lazy branches and the retained Unicode,
  decoding, parser/evaluator isolation, expansion and serialization checks in
  debug and release.
- [Mooncakes 0.1.9](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.9).
  The following docs-only commit records receipts; technical checks do not
  substitute for organizer final acceptance.

## 0.1.8 Unicode ordering audit (2026-10-30)

Reproduced a silent compatibility defect in 0.1.7: sort placed U+10000/emoji
before U+E000/U+FFFF due to UTF-16 code-unit comparison, and min/max selected
incorrect extremes. The JMESPath specification requires code-point ordering.
All six ordering functions now share an iterator-based code-point comparator.

Local checks: 46 unit tests; 892/892 official cases in each mode; 25 adverse
checks and 256 grammar mutations per mode; examples and PowerShell smoke.
New CLI vectors span empty strings, prefixes, combining sequences, BMP/astral
boundaries through U+10FFFF, string length/reversal and large/small finite
numbers. Unit tests also cover equal-key ordering and unchanged inputs.
Verified release evidence (2026-10-30):

- Source `24b1231b4a90c3b76b54e831fbbdee93badfeae4` is on existing main,
  with identical local/remote IDs and retained history.
  [CI 41036477186](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41036477186)
  passed on Windows and Ubuntu.
- 64-file archive inspected without credentials/build/cache files and fully
  verified after fresh extraction. SHA-256:
  `aa63db9a45cd5777b592d203eff74e0451d61348edb806e60aac1bfa8a025203`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
- A new consumer installed exact `JingLan0v0/jmespath@0.1.8` and passed all six
  Unicode ordering functions plus retained null, decoder, conversion, parser,
  evaluator, expansion and serialization regressions in debug and release.
- [Mooncakes 0.1.8](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.8).
  The following docs-only commit records these observations; official contest
  acceptance remains separate from technical verification.

## 0.1.7 CLI output and diagnostic audit (2026-10-30)

Reproduced in 0.1.6: stdout redirected to a read-only descriptor caused an
unhandled stream error, stack trace and exit 1. An invalid option containing
newline/ESC/bidi controls was printed verbatim into stderr. Both are fixed:
stream failures return exit 2 and a best-effort short diagnostic; embedded
diagnostic controls are escaped. Normal JSON stdout remains unchanged.

Local validation: 43 unit tests, both-mode 892/892 official cases, 25 adversarial
checks and 256 mutations per mode, examples and PowerShell smoke. Added CLI
tests run in debug/release for stdout failure, stderr failure, both unavailable,
closed downstream pipe and hostile diagnostic content. Output can be partial
if the destination fails after accepting some bytes; no atomic-output claim.
Verified release evidence (2026-10-30):

- Source `fe9cbc71daf054fa2e91e094ad53fba0d71a035d` is on existing main;
  [CI 41034982842](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/41034982842)
  passed Windows and Ubuntu, including the new real-process output tests.
- 64-file archive inspected without credentials, build or cache directories.
  Fresh-extraction full verification passed. SHA-256:
  `c198a3aaf1b7f1ff4f52cee963d5983492745f2114bfb44f00a84fc0d6c5e119`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
- A new consumer installed exact `JingLan0v0/jmespath@0.1.7` and passed all
  retained API regressions in both modes. The downloaded package's CLI was
  independently built in debug/release; its CLI integration suite passed,
  including unavailable outputs, closed pipe and diagnostic control escaping.
- [Mooncakes 0.1.7](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.7).
  Following docs-only commit records these receipts; organizer decisions remain
  separate. Previous commits/releases are retained for rollback and comparison.

## 0.1.6 decoder preflight audit (2026-10-29)

Closes the reproduced 12 MB escaped-string case left open in 0.1.5 by scanning
transport budgets before decoding. Both single-query and batch CLI now return
limit_exceeded, exit 2 and empty stdout under the same 192 MiB test heap. A
wide JSON array of objects is likewise rejected before construction. The 4.8 MB
conversion batch and prior parser/evaluator regressions still pass.

Local checks: 43 unit tests including exact preflight boundaries/duplicate keys;
three scenarios and public API example; 25 adversarial checks and 256 mutations
in each mode; official compliance 892/892 in debug and release; PowerShell smoke.
The scanner is not a second parser; normal syntax/escape decoding remains with
core JSON. New transport budgets deliberately restrict some previously accepted
inputs. Passing these cases is not a universal memory safety guarantee.

Verified release evidence (2026-10-29):

- Source `95be832ade24b6276c65687bd42fb83373f93738` is on existing main,
  preserving previous history. [CI 40836861937](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40836861937)
  passed on Windows and Ubuntu.
- Inspected 64-file archive; no credentials/build/cache directories. Fresh
  extraction passed full verification. SHA-256:
  `f42f280b62489c1591e5786f6e4268696202d505ff1d531f6039b06463d5cfa9`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
- Fresh consumer downloaded exact `JingLan0v0/jmespath@0.1.6` and passed public
  parse_json_bounded checks, over-limit rejection and all retained consumer
  regressions (conversion, null semantics, parser/evaluator isolation, expansion
  and serialization) in debug and release.
- [Mooncakes 0.1.6](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.6).
  The following docs-only commit records these receipts; organizer acceptance
  remains pending.

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
claimed fixed by 0.1.5. See resource-limits.md.

Verified release evidence (2026-10-29):

- Source commit `a763059841b44be838b0686b9ad23a21e4392b64` pushed to existing main.
  [CI 40834983084](https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/40834983084)
  passed on Windows and Ubuntu. Prior Git history is retained.
- Baseline 0.1.4 archive reproduced exit 134 / no output for the 4.8 MB
  conversion in both debug and release; `type(@)` on identical data exited 0.
- 61-file archive inspected with no credentials/build/cache directories;
  fresh-extraction full verification passed. SHA-256:
  `b505de436451a2215027415a2784eded3f7f9699644da15dd18e62954fd131c7`.
- Preflight returned 202 dry-run success; formal publication returned **200 OK**.
  A fresh consumer downloaded exact `JingLan0v0/jmespath@0.1.5` and passed
  conversion, null semantics, parser/evaluator isolation, expansion and bounded
  serialization checks in debug and release.
- [Mooncakes 0.1.5](https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.5).
  The following documentation-only commit records these receipts. Final
  organizer acceptance is still pending.

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
