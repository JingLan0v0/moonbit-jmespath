# MoonJMES project guide

This repository is the MoonBit JMESPath implementation started in September
2026 and approved for October initial review (participant-supplied organizer
notice). Read `docs/progress.md` and `docs/competition.md` before changing release or
competition claims. The main verification commands are `moon test --target js`,
`node scripts/conformance.mjs`, and `node scripts/verify.mjs`.

For recurring requests such as "继续优化", "再优化一轮" or "继续跑", read
`docs/optimization-plan.md` and resume its first unfinished work item after
checking current state. Update its checkpoint and evidence at the end of each
round. New user instructions take priority. Do not invent defects or rerun old
checks without a purpose; preserve the distinction between local, CI and release
evidence. This workflow runs on user requests, not an unattended schedule.

Production library code is in the root package. `cli/` owns argument parsing;
`cmd/main/` contains the Node.js host adapter only. Keep filesystem and process
APIs out of the reusable library. `examples/` contains three acceptance
scenarios. Resource limits are part of the public contract and must not be
removed to improve benchmark numbers.

The conformance script downloads the official vectors to a temporary directory
at a pinned revision. Do not commit those upstream JSON files unless their
redistribution terms become explicit. Never commit `.tools`, credentials,
`_build`, or downloaded caches.

Run `moon fmt`, `moon info`, and the complete verification before a release.
Only claim CI, Mooncakes publication, or official acceptance after the linked
external system shows the corresponding result.

The September parser crash and the October evaluator overflow are separate
regressions. Run `scripts/verify.mjs` (including timed adversarial subprocesses)
and official compliance in both debug and `--release` modes. Keep all limits
documented in `docs/resource-limits.md`; do not advertise absolute crash freedom
or guaranteed organizer acceptance based on passing a finite test suite.
