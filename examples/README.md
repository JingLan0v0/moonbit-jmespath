# Runnable examples

Run the demo from the repository root with the pinned MoonBit and Node.js.
Put `moon` on PATH or set `MOON_BIN` and `MOON_HOME` to the same installation.

```sh
node examples/demo.mjs
node examples/demo.mjs --release
```

The script builds the CLI, compares each scenario with committed JSON, and
prints the checked results. It also checks the quick start query and these two
batch boundaries.

- A decoded batch contains a normal request, a deeply nested expression that
  returns `limit_exceeded`, and a final successful request. Exit status is 0.
- An invalid outer JSON document returns `invalid_json`, exit status 2, and
  empty stdout.

Both modes run the demo during `node scripts/verify.mjs`.

## Windows PowerShell

The wrapper can select a pinned local installation for MoonBit commands.

```powershell
.\scripts\moon.ps1 version --all
.\scripts\moon.ps1 run cmd/main --target js -- --compact "instances[?state == 'running'].id" examples/cloud-inventory.json
.\examples\run.ps1
```

The scenario runner also accepts invocation by full path from another directory.

## Individual examples

For one scenario, run:

```text
moon run cmd/main --target js -- "sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}" examples/costs.json
```

Compare with `examples/expected/costs.json`. Run the complete public API example
with `moon run examples/library --target js`. The small batch fixture can also
be run on its own.

```sh
moon run cmd/main --target js -- --batch examples/batch.json
```

It returns `Ada`, an `invalid_arity` error, and `fallback`.

## 1. Cloud inventory

`instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}`

Selects the IDs and zones of production instances that are currently running.

## 2. Deployment policy findings

`deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}`

Extracts blocked deployments and their machine-readable reason codes.

## 3. Cost report

`sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}`

Creates a stable ascending cost view for a report or dashboard.
