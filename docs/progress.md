# Project status and handoff

## Current state

- Project: MoonJMES, module `JingLan0v0/jmespath`, version 0.1.0.
- Repository target: `https://github.com/JingLan0v0/moonbit-jmespath`.
- Core engine, standard functions, public APIs, batch mode, and CLI are complete.
- Local MoonBit tests pass on the JS target.
- Official JMESPath suite: 892/892 at pinned commit
  `53abcc37901891cf4308fcd910eab287416c4609`.
- Three acceptance scenarios and expected outputs are committed.
- GitHub CI and Mooncakes publication must be recorded here only after external
  verification succeeds.

## Release checklist

1. Run `node scripts/verify.mjs` and `node scripts/conformance.mjs`.
2. Confirm a clean `git status` and at least ten meaningful commits.
3. Create the public GitHub repository and push `main`.
4. Confirm the GitHub Actions matrix is green.
5. Run `moon publish --dry-run`, inspect the archive, then publish 0.1.0.
6. Install `JingLan0v0/jmespath` in a fresh consumer project and run a query.
7. Update this file with exact GitHub Actions and Mooncakes links.

## Competition evidence

The project has a distinct standards-based scope, a reproducible CLI, library
APIs, three scenarios, bounded untrusted-input handling, cross-platform CI, and
an objective external compatibility oracle. Official qualification and support
payments remain decisions of the organizer; local evidence is not acceptance.
