# Publishing and release verification

Module: JingLan0v0/jmespath.
Repository: https://github.com/JingLan0v0/moonbit-jmespath

Use the existing account session; never commit or paste credentials.json.

1. Keep moon.mod and model.mbt version() identical. Published versions cannot be
   overwritten; preserve older releases for comparison.
2. Use toolchain.json. Run moon fmt, moon info --target js, scripts/verify.mjs,
   and scripts/conformance.mjs in debug and --release modes. On Windows also
   run scripts/powershell-smoke.ps1.
3. Review git diff --check, generated interfaces, limits and changelog. Push
   normal commits to main and verify Windows/Ubuntu CI on that commit.
4. Run ./scripts/moon.ps1 publish --dry-run (or moon publish --dry-run).
   This pinned CLI may exit nonzero for a server **202 Accepted / Dry run
   completed successfully**. That response is only a preflight, not publication.
   Inspect _build/publish/ and confirm credentials, toolchains, caches, .git and
   _build contents are excluded.
5. Formal publication: ./scripts/moon.ps1 publish. Require a registry success
   response; install the exact version in a fresh consumer and exercise query,
   bounded serialization and batch APIs. Record evidence in acceptance.md.
6. A timeout is ambiguous. Check the exact registry version before retrying.
   Never infer publication from login or dry-run output.

Only the verified version in acceptance.md should be described as published.
GitHub main may include later documentation-only evidence commits.
