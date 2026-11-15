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

  $expectedUnicode = [string][char]0x6708 + [char]::ConvertFromUtf32(0x1f600)
  $unicodePayload = '{"value":"' + $expectedUnicode + '"}'
  $previousPipelineEncoding = $OutputEncoding
  $previousConsoleEncoding = [Console]::OutputEncoding
  try {
    $OutputEncoding = [Text.Encoding]::ASCII
    [Console]::OutputEncoding = [Text.Encoding]::GetEncoding(437)
    $unicodeResult = $unicodePayload | .\scripts\moon.ps1 run cmd/main --target js -- --compact value -
    if ($LASTEXITCODE -ne 0 -or ($unicodeResult | ConvertFrom-Json) -cne $expectedUnicode) {
      throw 'PowerShell wrapper did not preserve Unicode JSON.'
    }
    if ($OutputEncoding.CodePage -ne 20127 -or [Console]::OutputEncoding.CodePage -ne 437) {
      throw 'PowerShell wrapper changed caller encodings.'
    }
  } finally {
    $OutputEncoding = $previousPipelineEncoding
    [Console]::OutputEncoding = $previousConsoleEncoding
  }

  if ($PSVersionTable.PSVersion -ge [version]'7.3') {
    $PSNativeCommandArgumentPassing = 'Legacy'
  }
  $quotedPayload = '{"user.name":"dotted","first name":"space","say \"hi\"":"quoted","ends\\":"slash"}'
  $quotedQuery = '["user.name", "first name", "say \"hi\"", "ends\\"]'
  $quotedResult = $quotedPayload | .\scripts\moon.ps1 run cmd/main --target js -- --compact $quotedQuery -
  if ($LASTEXITCODE -ne 0 -or $quotedResult -cne '["dotted","space","quoted","slash"]') {
    throw "PowerShell wrapper changed quoted query arguments: $quotedResult"
  }
  if ($PSVersionTable.PSVersion -ge [version]'7.3' -and $PSNativeCommandArgumentPassing -ne 'Legacy') {
    throw 'PowerShell wrapper changed the caller native argument preference.'
  }

  $failureLog = [IO.Path]::GetTempFileName()
  $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
  try {
    $PSNativeCommandUseErrorActionPreference = $true
    foreach ($badQuery in @('length()', '["a.b",length()]')) {
      $failureOutput = '{"a.b":"value"}' | .\scripts\moon.ps1 run cmd/main --target js -- --compact $badQuery - 2> $failureLog
      $failureCode = $LASTEXITCODE
      if ($failureCode -ne 2 -or $null -ne $failureOutput) {
        throw "Expected failure exit 2 with empty stdout, got exit $failureCode and output <$failureOutput>."
      }
      if ((Get-Content -Raw -LiteralPath $failureLog) -notmatch 'moon-jmes: invalid_arity') {
        throw 'PowerShell wrapper did not leave the diagnostic on the error stream.'
      }
    }
    if (-not $PSNativeCommandUseErrorActionPreference -or $ErrorActionPreference -ne 'Stop') {
      throw 'PowerShell wrapper changed the caller error preferences.'
    }
  } finally {
    $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    Remove-Item -LiteralPath $failureLog
  }

  $versionLine = (Get-Content -LiteralPath moon.mod | Where-Object { $_ -match '^version = "' } | Select-Object -First 1)
  if ($versionLine -notmatch '^version = "([^"]+)"') { throw 'Module version missing.' }
  $version = $Matches[1]
  $actualVersion = .\scripts\moon.ps1 run cmd/main --target js -- --version
  if ($LASTEXITCODE -ne 0 -or $actualVersion.Trim() -ne $version) {
    throw 'PowerShell wrapper version does not match moon.mod.'
  }
  Write-Host 'PASS PowerShell wrapper: pipeline, Unicode, quoted arguments, exit status, and version'
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
