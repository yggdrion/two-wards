# Rebuilds SpriteFrames and TileSet resources in game/resources/generated/ from the
# PNGs listed in game/assets/manifest.json, using the pinned Godot version.
# PowerShell counterpart of build_assets.sh.
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1') }

Push-Location (Join-Path $Root 'game')
try {
    # Import first so new or changed PNGs are loadable.
    & { $ErrorActionPreference = 'Continue'; & $Godot --headless --import 2>&1 | Out-Null }
    & $Godot --headless --script res://tools/build_assets.gd
    $ExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $ExitCode
