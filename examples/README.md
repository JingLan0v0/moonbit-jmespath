# Acceptance scenarios

From the repository root run `./examples/run.ps1` on Windows to check all three
scenarios, or `node scripts/verify.mjs` on either supported CI OS. The PowerShell
script also accepts invocation by full path from another directory.

For one scenario, run:

```text
moon run cmd/main --target js -- "sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}" examples/costs.json
```

Compare with `examples/expected/costs.json`. `library/` is a complete library
consumer (`moon run examples/library --target js`); `batch.json` is a batch
input with two successes and one isolated error (`--batch examples/batch.json`).

## 1. Cloud inventory

`instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}`

Selects the IDs and zones of production instances that are currently running.

## 2. Deployment policy findings

`deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}`

Extracts blocked deployments and their machine-readable reason codes.

## 3. Cost report

`sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}`

Creates a stable ascending cost view for a report or dashboard.
