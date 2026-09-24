# Third-party notices

MoonJMES is an independent implementation of the public JMESPath specification.

`scripts/conformance.mjs` downloads test vectors at verification time from the
public `jmespath/jmespath.test` repository, pinned to commit
`53abcc37901891cf4308fcd910eab287416c4609`. Those files are cached only in the
user's temporary directory and are not copied into MoonJMES source archives or
release artifacts.

No source code from another JMESPath implementation is included.
