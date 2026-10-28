# Contributing

Use the compiler and Node.js versions in `toolchain.json`. Keep library logic
in MoonBit; Node-specific I/O belongs in `cmd/main/host.mbt`. Preserve public
resource limits and existing Git history. Read `AGENTS.md` and `docs/progress.md`
when resuming work.

Before submitting a change, run:

```text
moon fmt
moon info --target js
node scripts/verify.mjs
node scripts/conformance.mjs
node scripts/conformance.mjs --release
```

`moon` must be on PATH or set `MOON_BIN` to its executable and `MOON_HOME` to
the matching installation. On Windows, also run `./scripts/powershell-smoke.ps1`.
Use `scripts/moon.ps1` for individual Moon commands when using the local toolchain.
Commit generated `.mbti` changes only when the intended API changes.

Add behavioral regressions for bug fixes. Test normal values, boundary values,
and failure isolation. Runtime crash fixes must include a subprocess with a
timeout in both debug and release; a passing unit test alone is insufficient.
The official compliance suite is pinned and cached outside the repository.
New local regressions supplement it; never change upstream expected results
to hide incompatibilities. Keep README examples executable against committed data.

Report bugs with the version, expression, minimal non-sensitive JSON, expected
and actual result, target, build mode and exit code. Remove tokens and private
data before posting an issue on the existing GitHub repository.

For releases, follow `docs/publishing.md`. Do not equate a dry run, passing local
tests, successful CI, a registry upload or organizer acceptance. Record each
observed result separately in `docs/acceptance.md`.
