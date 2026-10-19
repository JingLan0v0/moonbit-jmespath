# Project status and handoff

## Current state (2026-10-19)

- Project: MoonJMES, MoonBit module `JingLan0v0/jmespath`.
- Repository: `https://github.com/JingLan0v0/moonbit-jmespath`.
- The owner reports that the project passed the competition's initial review.
  This is owner-provided status, not an independently verified organizer result.
- Version 0.1.2 is public on Mooncakes:
  `https://mooncakes.io/docs/JingLan0v0/jmespath@0.1.2`. Version 0.1.1 remains
  available for historical comparison. See `docs/acceptance.md` for the
  September parser crash and fresh-consumer repair evidence.
- The pure MoonBit library includes the JMESPath engine, standard functions,
  compiled expressions, one-shot calls, and isolated batch results. The JS
  command-line host reads files or stdin through Node.js.
- Local JS-target verification passes: formatting, compiler checks, MoonBit
  tests, generated interfaces, CLI integration tests, and three scenarios.
- The local conformance rerun was blocked by an external vector download, but
  the published source commit `f569c4f` passed 892/892 official cases in both
  Windows and Ubuntu GitHub Actions jobs. See `docs/acceptance.md`.
- PowerShell pipeline and CLI version checks pass locally.

## Evidence and release boundary

- The current 0.1.2 source passed both Ubuntu and Windows in
  `https://github.com/JingLan0v0/moonbit-jmespath/actions/runs/39249597919`.
- A separate consumer project previously installed
  `JingLan0v0/jmespath@0.1.1`, compiled it, and evaluated
  `items[*].name` to `["moon","bit"]`.
- The 0.1.2 release is published and tested from a new module. Direct Git
  transport could not reach GitHub, and the connected GitHub app lacked write
  permission. The owner's existing Git credential was used with GitHub's
  official API to write the same reviewed file tree to public `main` in a
  single commit, preserving older remote history. Remote source commit
  `f569c4f` and its cross-platform CI were independently verified. The local
  Git commit chain has the same file tree but different intermediate commit
  hashes; reconcile local history with the remote branch before a later push.
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
