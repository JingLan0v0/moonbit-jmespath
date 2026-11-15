[CmdletBinding(PositionalBinding=$false)]
param(
  [Parameter(ValueFromPipeline=$true)][string]$InputLine,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$MoonArgs
)

begin {
  $ErrorActionPreference = 'Stop'
  $pipelineLines = [Collections.Generic.List[string]]::new()
}

process {
  if ($null -ne $InputLine) {
    $pipelineLines.Add($InputLine)
  }
}

end {
  $projectRoot = Split-Path $PSScriptRoot -Parent
  $toolchain = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'toolchain.json') | ConvertFrom-Json
  $localToolchain = Join-Path (Split-Path $projectRoot -Parent) ".tools/moonjmes-$($toolchain.moonbit_install_version)"
  $localMoon = Join-Path $localToolchain 'bin/moon.exe'
  $previousMoonHome = $env:MOON_HOME

  if ($env:MOON_BIN) {
    $moonExecutable = (Get-Command $env:MOON_BIN -CommandType Application -ErrorAction Stop).Source
  } elseif (Test-Path -LiteralPath $localMoon -PathType Leaf) {
    $env:MOON_HOME = $localToolchain
    $moonExecutable = $localMoon
  } else {
    $moonExecutable = (Get-Command moon -ErrorAction Stop).Source
  }

  $utf8 = [Text.UTF8Encoding]::new($false)
  $previousConsoleEncoding = [Console]::OutputEncoding
  $useUtf8Console = $previousConsoleEncoding.CodePage -ne $utf8.CodePage

  Push-Location $projectRoot
  try {
    if ($useUtf8Console) {
      [Console]::OutputEncoding = $utf8
    }
    if ($pipelineLines.Count -gt 0) {
      $OutputEncoding = $utf8
      $pipelineLines | & $moonExecutable @MoonArgs
    } else {
      & $moonExecutable @MoonArgs
    }
    $result = $LASTEXITCODE
  } finally {
    if ($useUtf8Console) {
      [Console]::OutputEncoding = $previousConsoleEncoding
    }
    Pop-Location
    $env:MOON_HOME = $previousMoonHome
  }
  exit $result
}
