# Project status and handoff

## Current state (2026-10-01)

- Project: MoonJMES, MoonBit module `JingLan0v0/jmespath`.
- Repository: `https://github.com/JingLan0v0/moonbit-jmespath`.
- The owner reports that the project passed the competition's initial review.
  This is owner-provided status, not an independently verified organizer result.
- Version 0.1.1 is public on Mooncakes:
  `https://mooncakes.io/docs/JingLan0v0/jmespath`.
- The changes in the `Unreleased` section of `CHANGELOG.md` are repository
  changes. They are not included in the published Mooncakes 0.1.1 package.
- The pure MoonBit library includes the JMESPath engine, standard functions,
  compiled expressions, one-shot calls, and isolated batch results. The JS
  command-line host reads files or stdin through Node.js.
- Local JS-target verification passes: formatting, compiler checks, MoonBit
  tests, generated interfaces, CLI integration tests, and three scenarios.
- Official JMESPath compliance: 892/892 at pinned revision
  `53abcc37901891cf4308fcd910eab287416c4609`.
- PowerShell pipeline and CLI version checks pass locally.

## Evidence and release boundary

- The previous Ubuntu/Windows CI run passed for an earlier commit:
  `https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/35997809718`.
  Check the Actions page for the status of any newer commit.
- A separate consumer project previously installed
  `JingLan0v0/jmespath@0.1.1`, compiled it, and evaluated
  `items[*].name` to `["moon","bit"]`.
- The current repository contains new boundary fixes and tests. A later
  Mooncakes version will require an authenticated publish and a new consumer
  check; GitHub synchronization alone does not update Mooncakes.
- Final competition acceptance and support payments are organizer decisions.

## Continuation checklist

1. Run `node scripts/verify.mjs` and `node scripts/conformance.mjs` with the
   pinned MoonBit toolchain available as `moon` or `MOON_BIN`.
2. On Windows, run `./scripts/powershell-smoke.ps1`.
3. Inspect `git diff --check`, generated `.mbti` interfaces, and package files.
4. After a push, confirm both Ubuntu and Windows jobs on the new commit.
5. Before a Mooncakes release, increment the version consistently, run the
   publish dry run with an authenticated account, publish, and validate a new
   installation from a fresh consumer project.
