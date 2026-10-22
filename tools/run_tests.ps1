# Runs all gdUnit4 tests headless with the pinned Godot version.
# PowerShell counterpart of run_tests.sh. Extra arguments go to gdUnit4,
# e.g. .\tools\run_tests.ps1 -a res://tests/tower_test.gd
# Set $env:GODOT_BIN to use your own binary; it must match .godot-version.
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content (Join-Path $Root '.godot-version') -Raw).Trim()
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1') }

$Actual = (& $Godot --headless --version | Select-Object -Last 1).Trim()
if (-not $Actual.StartsWith("$Version.stable.")) {
    throw "GODOT_BIN is Godot $Actual, but .godot-version pins $Version"
}

& (Join-Path $PSScriptRoot 'install_gdunit4.ps1')

Push-Location (Join-Path $Root 'game')
try {
    # Import once so class_name scripts and resources are registered.
    & $Godot --headless --import 2>&1 | Out-Null
    $TestArgs = @('--headless', '--ignoreHeadlessMode', '-a', 'res://tests') + $args
    # Same invocation as addons/gdUnit4/runtest.sh. The unreachable remote debugger
    # keeps Godot from dropping into its interactive debugger on script errors.
    & $Godot --path . -s -d --remote-debug tcp://127.0.0.1:0 `
        res://addons/gdUnit4/bin/GdUnitCmdTool.gd @TestArgs
    $ExitCode = $LASTEXITCODE
    Write-Host "Run tests ends with $ExitCode"
    & $Godot --headless --path . --quiet -s res://addons/gdUnit4/bin/GdUnitCopyLog.gd @TestArgs | Out-Null
} finally {
    Pop-Location
}
exit $ExitCode
