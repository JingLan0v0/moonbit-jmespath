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
  $toolchains = @(
    (Join-Path (Split-Path $projectRoot -Parent) '.tools/moonjmes-toolchain'),
    (Join-Path (Split-Path $projectRoot -Parent) '.tools/moon')
  )
  $localToolchain = $toolchains | Where-Object {
    Test-Path -LiteralPath (Join-Path $_ 'bin/moon.exe')
  } | Select-Object -First 1

  if ($localToolchain) {
    $env:MOON_HOME = $localToolchain
    $moonExecutable = Join-Path $localToolchain 'bin/moon.exe'
  } else {
    $moonExecutable = (Get-Command moon -ErrorAction Stop).Source
  }

  Push-Location $projectRoot
  try {
    if ($pipelineLines.Count -gt 0) {
      $pipelineLines | & $moonExecutable @MoonArgs
    } else {
      & $moonExecutable @MoonArgs
    }
    $result = $LASTEXITCODE
  } finally {
    Pop-Location
  }
  exit $result
}
