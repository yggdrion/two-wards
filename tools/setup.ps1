# One-time setup of a dev machine; safe to re-run. Installs the pinned Python packages
# (gdtoolkit, pillow, pre-commit), the pinned Godot and gdUnit4, the pre-commit and
# pre-push hooks, then runs the quick check.
# PowerShell counterpart of setup.sh. Needs: Python 3 and git on PATH.
# Not installed here: export templates (export.ps1 fetches them on first use).
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
    function Invoke-Native([string]$Exe) {
        & $Exe @args
        if ($LASTEXITCODE) { throw "$Exe $args failed (exit $LASTEXITCODE)" }
    }

    # Same python as check.ps1.
    $OnPath = Get-Command python -ErrorAction SilentlyContinue
    $Python = if ($OnPath -and $OnPath.Source -notlike '*\WindowsApps\*') { 'python' } else { 'py' }

    Write-Host '== Python packages'
    Invoke-Native $Python -m pip install --disable-pip-version-check -r tools/requirements.txt
    Write-Host "`n== Godot"
    & (Join-Path $PSScriptRoot 'install_godot.ps1') | Out-Null
    Write-Host "`n== gdUnit4"
    & (Join-Path $PSScriptRoot 'install_gdunit4.ps1')
    Write-Host "`n== Git hooks"
    Invoke-Native $Python -m pre_commit install
    & (Join-Path $PSScriptRoot 'check.ps1') -InstallHook
    & (Join-Path $PSScriptRoot 'check.ps1') -Quick
    if ($LASTEXITCODE) { throw 'Quick check failed' }
    Write-Host "`nSetup done. Run .\tools\check.ps1 for the full check."
} finally {
    Pop-Location
}
