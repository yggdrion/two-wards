# Exports a release build with the pinned Godot version and export templates.
# PowerShell counterpart of export.sh.
# Usage: .\tools\export.ps1 <linux|windows> [output dir, default build/<platform>]
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
switch ($args[0]) {
    'linux' { $Preset = 'Linux'; $File = 'two-wards.x86_64' }
    'windows' { $Preset = 'Windows Desktop'; $File = 'two-wards.exe' }
    default { throw 'Usage: .\tools\export.ps1 <linux|windows> [output dir]' }
}
$Out = $args[1]
if (-not $Out) { $Out = Join-Path $Root "build/$($args[0])" }

$Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1')
& (Join-Path $PSScriptRoot 'install_godot_templates.ps1') | Out-Null

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$OutFile = Join-Path (Resolve-Path $Out).Path $File
Push-Location (Join-Path $Root 'game')
try {
    # Import once so class_name scripts and resources are registered.
    & $Godot --headless --import 2>&1 | Out-Null
    & $Godot --headless --export-release $Preset $OutFile
} finally {
    Pop-Location
}
# Godot can exit 0 after a failed export, so check the result.
if (-not (Test-Path $OutFile) -or (Get-Item $OutFile).Length -eq 0) {
    throw "Export of $Preset produced no $OutFile"
}
Write-Host "Exported $Preset to $OutFile"
