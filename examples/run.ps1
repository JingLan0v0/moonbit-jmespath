$ErrorActionPreference = 'Stop'
$moon = if ($env:MOON_BIN) { $env:MOON_BIN } else { 'moon' }
$cases = @(
  @{ Name='cloud-inventory'; Expression="instances[?environment == 'prod' && state == 'running'].{id: id, zone: zone}" },
  @{ Name='deployments'; Expression="deployments[?decision == 'deny'].{service: service, reasons: reasons[*].code}" },
  @{ Name='costs'; Expression='sort_by(services, &monthly_cost)[*].{service: name, monthly_cost: monthly_cost}' }
)
foreach ($case in $cases) {
  $actual = & $moon run cmd/main --target js -- --compact $case.Expression "examples/$($case.Name).json"
  if ($LASTEXITCODE -ne 0) { throw "$($case.Name) failed" }
  $expected = Get-Content -Raw -LiteralPath "examples/expected/$($case.Name).json"
  if (($actual | ConvertFrom-Json | ConvertTo-Json -Depth 20 -Compress) -ne ($expected | ConvertFrom-Json | ConvertTo-Json -Depth 20 -Compress)) {
    throw "$($case.Name) output did not match expected JSON"
  }
  Write-Host "PASS $($case.Name)"
}
