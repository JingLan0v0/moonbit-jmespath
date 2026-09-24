# Acceptance scenarios

## 1. Cloud inventory

`instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}`

Selects the IDs and zones of production instances that are currently running.

## 2. Deployment policy findings

`deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}`

Extracts blocked deployments and their machine-readable reason codes.

## 3. Cost report

`sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}`

Creates a stable ascending cost view for a report or dashboard.
