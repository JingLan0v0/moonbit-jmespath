[CmdletBinding(PositionalBinding=$false)]
param(
  [Parameter(ValueFromPipeline=$true)][string]$InputLine,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$MoonArgs
)

begin {
  $ErrorActionPreference = 'Stop'
  $pipelineLines = [Collections.Generic.List[string]]::new()
  $usePipelineInput = $MyInvocation.ExpectingInput -or $PSBoundParameters.ContainsKey('InputLine')
}

process {
  if ($PSBoundParameters.ContainsKey('InputLine')) {
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
  $executable = $moonExecutable
  $nativeArgs = $MoonArgs
  $hasStandardArguments = $PSVersionTable.PSVersion -ge [version]'7.3'
  $forwardLegacyArguments = -not $hasStandardArguments -and ($MoonArgs -contains '' -or ($MoonArgs -match '"'))
  $previousLegacyArgs = $env:MOONJMES_LEGACY_ARGS

  Push-Location $projectRoot
  try {
    if ($useUtf8Console) {
      [Console]::OutputEncoding = $utf8
    }
    if ($hasStandardArguments) {
      $PSNativeCommandArgumentPassing = 'Standard'
    } elseif ($forwardLegacyArguments) {
      # Older PowerShell native argument handling strips embedded quotes.
      $executable = (Get-Command node -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
      $nativeArgs = @((Join-Path $PSScriptRoot 'invoke-moon.cjs'), $moonExecutable)
      $env:MOONJMES_LEGACY_ARGS = ConvertTo-Json -InputObject $MoonArgs -Compress
    }
    # Let the caller handle the native exit code. Older shells turn stderr into error records.
    $PSNativeCommandUseErrorActionPreference = $false
    if ($PSVersionTable.PSVersion -lt [version]'7.2') {
      $ErrorActionPreference = 'Continue'
    }
    if ($usePipelineInput) {
      $OutputEncoding = $utf8
      $pipelineLines | & $executable @nativeArgs
    } else {
      & $executable @nativeArgs
    }
    $result = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = 'Stop'
    if ($useUtf8Console) {
      [Console]::OutputEncoding = $previousConsoleEncoding
    }
    if ($forwardLegacyArguments) {
      $env:MOONJMES_LEGACY_ARGS = $previousLegacyArgs
    }
    Pop-Location
    $env:MOON_HOME = $previousMoonHome
  }
  exit $result
}
