# MoonJMES 0.1.2 repair evidence (2026-10-19)

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
download its vectors on this machine during this check because the GitHub raw
endpoint reset the connection. Earlier repository evidence records 892/892;
the new source must be checked again by CI on the final GitHub commit before
claiming current cross-platform conformance. GitHub synchronization is pending
until the remote `main` head can be read back with the 0.1.2 manifest and the
Windows/Ubuntu workflow succeeds. Technical repair and package publication do
not imply that the September organizer reopened or accepted the application.
