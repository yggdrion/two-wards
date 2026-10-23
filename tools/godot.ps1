# Runs the pinned Godot version, installing it first if needed.
# Example: .\tools\godot.ps1 --path game -e
$ErrorActionPreference = 'Stop'

$Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1')
# Running the game skips the class_name scan the editor does, so a checkout that pulled new
# scripts would fail with "Could not find type". Import first; it is quick when up to date.
if (-not ($args -contains '-e' -or $args -contains '--editor' -or $args -contains '--import')) {
    # Only --path: other args (--quit-after, game args) could cut the import short.
    $i = [array]::IndexOf($args, '--path')
    $PathArg = if ($i -ge 0) { @('--path', $args[$i + 1]) } else { @() }
    & { $ErrorActionPreference = 'Continue'; & $Godot --headless --import @PathArg 2>&1 | Out-Null }
}
& $Godot @args
exit $LASTEXITCODE
