# Changelog

All notable changes to MoonJMES are recorded here.

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
