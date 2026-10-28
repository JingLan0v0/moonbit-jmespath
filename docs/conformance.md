# JMESPath conformance

The implementation passes **892 of 892 cases** from the official
`jmespath/jmespath.test` suite at commit
`53abcc37901891cf4308fcd910eab287416c4609`.

Run the independent check with:

```bash
node scripts/conformance.mjs
node scripts/conformance.mjs --release
```

The script builds the public CLI, downloads the pinned upstream JSON vectors to
the operating system's temporary directory, submits every case through the
public batch interface, and compares JSON results structurally. Expected error
cases pass only when the engine returns the expected error category (hyphens
normalized to underscores). The runner also checks the response count and uses
a subprocess timeout. If raw content download fails, it tries GitHub's official
contents API at the same pinned commit. No upstream test vectors are
redistributed in this repository.

Covered files: basic, boolean, current, escape, filters, functions,
identifiers, indices, literal, multiselect, pipe, slice, syntax, unicode, and
wildcard. The upstream benchmark data is intentionally excluded because it is
performance input rather than a conformance assertion.

Each mode writes a JSON summary under `_build/`; CI uploads these with the
general verification summary as one artifact per operating system. A successful
compliance run validates standard semantics; adversarial resource boundaries
are tested separately by `scripts/adversarial.mjs`.
