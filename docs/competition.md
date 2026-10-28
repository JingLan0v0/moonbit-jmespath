# October competition status and requirements

Updated: 2026-10-28. Project: moonbit-jmespath / MoonJMES.
Repository: https://github.com/JingLan0v0/moonbit-jmespath

The participant supplied an organizer email screenshot confirming **October
initial review approval** for this exact repository. The email asks for ongoing
development, traceable commits, clear README, license and usage instructions.
Final review evaluates completion, code quality, open-source compliance and
MoonBit relevance. It is not a final acceptance or payment receipt.

| Requirement | Stage | Evidence / status |
| --- | --- | --- |
| Initial approval for this repository | Registration | Participant-supplied organizer screenshot; no private email committed |
| Continue the approved JSON query project | Development | MoonBit parser, evaluator, functions and API; 0.1.3 adds execution/output hardening |
| Meaningful traceable changes | Development | Existing Git history retained; changelog separates earlier repair from October additions |
| README and usable examples | Engineering | English/Chinese README; three checked scenarios in examples/ |
| License and provenance | Open source | Apache-2.0 LICENSE and THIRD_PARTY_NOTICES.md; upstream vectors downloaded only during verification |
| Functional and robustness evidence | Engineering | verify.mjs, exact-category official tests in debug/release, Windows/Ubuntu CI |
| Release and installation evidence | Delivery | acceptance.md and publishing.md distinguish local, CI and registry states |
| Final acceptance | Organizer | Pending; initial approval and passing tests do not imply acceptance |
| Current final form, deadline, personal fields | Participant / organizer | Follow live form/group notice; no final-review submission receipt supplied in this audit |

Official homepage: https://moonbitlang.github.io/Hackathon2026/ . A 2026-10-21
retrieval returned no readable rules text, so this file does not derive current
deadlines, payments or extra materials from older events. The supplied October
email is the project-specific source. Extend this matrix if a later final-review
notice supplies additional requirements.

## September lesson and October contribution

September's review found a parser crash despite passing examples and standard
compliance tests; that case was repaired in 0.1.2. The 0.1.3 audit separately
reproduced an evaluator stack overflow and output amplification. It adds early
execution guards, iterative size/equality traversal, batch response budgets and
timed subprocess checks. Old work is not presented as new contribution.
