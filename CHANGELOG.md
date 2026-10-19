# Changelog

All notable changes to MoonJMES are recorded here.

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
