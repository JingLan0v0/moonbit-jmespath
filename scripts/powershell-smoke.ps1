$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
  $payload = '{"items":[{"name":"A","price":9},{"name":"B","price":12}]}'
  $result = $payload | .\scripts\moon.ps1 run cmd/main --target js -- 'items[?price >= `10`].name' -
  if ($LASTEXITCODE -ne 0) { throw 'PowerShell pipeline query failed.' }
  $values = @($result | ConvertFrom-Json)
  if ($values.Count -ne 1 -or $values[0] -ne 'B') {
    throw "Unexpected query output: $result"
  }

  $versionLine = (Get-Content -LiteralPath moon.mod | Where-Object { $_ -match '^version = "' } | Select-Object -First 1)
  if ($versionLine -notmatch '^version = "([^"]+)"') { throw 'Module version missing.' }
  $version = $Matches[1]
  $actualVersion = .\scripts\moon.ps1 run cmd/main --target js -- --version
  if ($LASTEXITCODE -ne 0 -or $actualVersion.Trim() -ne $version) {
    throw 'PowerShell wrapper version does not match moon.mod.'
  }
  Write-Host 'PASS PowerShell wrapper: pipeline and version'
  Push-Location ([IO.Path]::GetTempPath())
  try {
    $startingLocation = (Get-Location).Path
    & (Join-Path $projectRoot 'examples/run.ps1')
    if ((Get-Location).Path -ne $startingLocation) { throw 'Example runner changed caller directory.' }
  } finally {
    Pop-Location
  }
} finally {
  Pop-Location
}
