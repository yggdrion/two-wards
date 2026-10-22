# Runs the pinned Godot version, installing it first if needed.
# Example: .\tools\godot.ps1 --path game -e
$ErrorActionPreference = 'Stop'

$Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1')
& $Godot @args
exit $LASTEXITCODE
