param([Parameter(ValueFromRemainingArguments=$true)][string[]]$MoonArgs)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$localToolchain = Join-Path (Split-Path $projectRoot -Parent) '.tools/moon'
$localMoon = Join-Path $localToolchain 'bin/moon.exe'

if (Test-Path -LiteralPath $localMoon) {
  $env:MOON_HOME = $localToolchain
  $moonExecutable = $localMoon
} else {
  $moonExecutable = (Get-Command moon -ErrorAction Stop).Source
}

Push-Location $projectRoot
try {
  & $moonExecutable @MoonArgs
  $result = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $result
