# Project status and handoff

## Current state (2026-10-28)

### Additional audit: 0.1.4 source checkpoint

- Corrected null multi-select and null-left subexpression function semantics;
  preserved previous resource guards. Added three unit tests and both-mode CLI regressions.
- Added complete library example, batch file, API/error guide and contributor
  guide. Fixed quick-start paths and PowerShell invocation from another directory.
- Aligned the agent setup with the CI toolchain instead of downloading latest.
- Local checks passed: 37 unit tests, library example in both modes, three
  scenarios, CLI plus 20 adversarial/256 mutation checks per mode, 892 official
  cases in each mode, and PowerShell out-of-directory smoke.
- Next: normal commit to existing main, verify exact CI, publish/consume 0.1.4
  and append observed release evidence. Do not claim publication before success.

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
4. Push normal commits, verify the exact remote SHA and both CI jobs, and record their URLs. If publishing 0.1.3, follow publishing.md; a dry run is not publication, and a timeout requires checking the registry before retrying.
5. Install the exact published version in a new consumer project and exercise library batch isolation and bounded serialization. Update evidence only after observing the result. Do not guarantee organizer acceptance.
