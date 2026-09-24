# JMESPath conformance

The implementation passes **892 of 892 cases** from the official
`jmespath/jmespath.test` suite at commit
`53abcc37901891cf4308fcd910eab287416c4609`.

Run the independent check with:

```bash
node scripts/conformance.mjs
```

The script builds the public CLI, downloads the pinned upstream JSON vectors to
the operating system's temporary directory, submits every case through the
public batch interface, and compares JSON results structurally. Expected error
cases pass only when the engine returns an error. No upstream test vectors are
redistributed in this repository.

Covered files: basic, boolean, current, escape, filters, functions,
identifiers, indices, literal, multiselect, pipe, slice, syntax, unicode, and
wildcard. The upstream benchmark data is intentionally excluded because it is
performance input rather than a conformance assertion.
