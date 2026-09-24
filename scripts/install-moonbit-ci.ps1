$ErrorActionPreference = 'Stop'
if (-not $env:RUNNER_TEMP -or -not $env:GITHUB_PATH -or -not $env:GITHUB_ENV) {
  throw 'This installer is intended for GitHub Actions runners.'
}
$version = '0.10.14%2B7d59c7ec9'
$installRoot = Join-Path $env:RUNNER_TEMP 'moonjmes-toolchain'
$downloadRoot = Join-Path $env:RUNNER_TEMP 'moonjmes-downloads'
New-Item -ItemType Directory -Path $downloadRoot -Force | Out-Null

function Get-OfficialFile([string]$RelativePath, [string]$Destination) {
  foreach ($origin in @('https://cli.moonbitlang.com', 'https://cli.moonbitlang.cn')) {
    & curl.exe --fail --location --retry 2 --retry-delay 2 --connect-timeout 15 --max-time 90 --output $Destination "$origin/$RelativePath"
    if ($LASTEXITCODE -eq 0) { return }
  }
  throw "Could not download $RelativePath from official mirrors."
}

$binaryZip = Join-Path $downloadRoot 'moonbit.zip'
$coreZip = Join-Path $downloadRoot 'core.zip'
$checksums = Join-Path $downloadRoot 'moonbit.sha256'
Get-OfficialFile "binaries/$version/moonbit-windows-x86_64.zip" $binaryZip
Get-OfficialFile "binaries/$version/moonbit-windows-x86_64.sha256" $checksums
Get-OfficialFile "cores/core-$version.zip" $coreZip
Expand-Archive -LiteralPath $binaryZip -DestinationPath $installRoot
Expand-Archive -LiteralPath $coreZip -DestinationPath (Join-Path $installRoot 'lib')
$binRoot = [IO.Path]::GetFullPath((Join-Path $installRoot 'bin'))
$verified = 0
foreach ($line in Get-Content -LiteralPath $checksums) {
  if ($line -notmatch '^([a-fA-F0-9]{64})\s+(.+)$') { throw 'Invalid checksum entry.' }
  $target = [IO.Path]::GetFullPath((Join-Path $binRoot $Matches[2]))
  if (-not $target.StartsWith($binRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Checksum path escapes bin directory.' }
  if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLower() -ne $Matches[1].ToLower()) { throw "Checksum mismatch: $target" }
  $verified++
}
if ($verified -lt 1) { throw 'No binaries verified.' }
$env:MOON_HOME = $installRoot
$env:PATH = $binRoot + ';' + $env:PATH
Push-Location (Join-Path $installRoot 'lib/core')
try { & (Join-Path $binRoot 'moon.exe') bundle --target js --warn-list '-a' } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'Core JS bundle failed.' }
"MOON_HOME=$installRoot" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
$binRoot | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
Write-Host "Pinned MoonBit installed; $verified checksums verified."
