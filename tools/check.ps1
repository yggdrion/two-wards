# Runs the same checks as CI locally, in CI order, and stops at the first failure:
#   1. gdlint + gdformat --check     2. asset validator + its unittest suite
#   3. gdUnit4 tests (pinned Godot)  4. generated assets are up to date
# PowerShell counterpart of check.sh.
# Usage: .\tools\check.ps1 [-Quick] [-Export] [-InstallHook]
#   -Quick        only steps 1 and 2 (no Godot), a few seconds
#   -Export       also export the Windows build to build/windows/ (for playtests)
#   -InstallHook  install a git pre-push hook that runs this script, then exit
# Needs: pip install "gdtoolkit==4.5.0" -r tools/requirements.txt
param([switch]$Quick, [switch]$Export, [switch]$InstallHook)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
try {
    if ($InstallHook) {
        $Hook = Join-Path (git rev-parse --git-path hooks) 'pre-push'
        Copy-Item (Join-Path $PSScriptRoot 'pre-push') $Hook -Force
        Write-Host "Installed $Hook (skip once with: git push --no-verify)"
        exit 0
    }

    # Native commands don't throw on a non-zero exit in PowerShell 5.1, so check each one.
    function Invoke-Step([string]$Name, [scriptblock]$Block) {
        Write-Host "`n== $Name"
        & $Block
        if ($LASTEXITCODE) { throw "$Name failed (exit $LASTEXITCODE)" }
    }
    function Invoke-Native([string]$Exe) {
        & $Exe @args
        if ($LASTEXITCODE) { throw "$Exe $args failed (exit $LASTEXITCODE)" }
    }

    # Prefer the python on PATH, where pip installed gdtoolkit and pillow; the py launcher
    # can pick a different version. The WindowsApps python is only a Store installer stub.
    $OnPath = Get-Command python -ErrorAction SilentlyContinue
    $Python = if ($OnPath -and $OnPath.Source -notlike '*\WindowsApps\*') { 'python' } else { 'py' }
    if (-not (Get-Command gdlint -ErrorAction SilentlyContinue)) {
        throw 'gdlint not found: pip install "gdtoolkit==4.5.0"'
    }

    Invoke-Step 'Lint and format' {
        Invoke-Native gdlint game/scripts game/tests game/tools
        Invoke-Native gdformat --check game/scripts game/tests game/tools
    }
    Invoke-Step 'Asset validator' {
        Invoke-Native $Python -m unittest discover -s tools -p 'test_*.py'
        Invoke-Native $Python tools/validate_assets.py
    }
    if ($Quick) {
        Write-Host "`nQuick checks passed (Godot tests skipped)."
        exit 0
    }

    Invoke-Step 'gdUnit4 tests' { & (Join-Path $PSScriptRoot 'run_tests.ps1') }

    # Compare before and after, so local uncommitted work does not count as drift.
    function Get-Snapshot { ((git status --porcelain game/) + (git diff game/)) -join "`n" }
    Invoke-Step 'Generated assets up to date' {
        $Before = Get-Snapshot
        & (Join-Path $PSScriptRoot 'build_assets.ps1') | Out-Null
        if ($LASTEXITCODE) { return }
        if ((Get-Snapshot) -ne $Before) {
            git status --porcelain game/
            throw 'build_assets changed files under game/: commit the regenerated .tres and .import files.'
        }
    }

    if ($Export) {
        Invoke-Step 'Export' { & (Join-Path $PSScriptRoot 'export.ps1') windows }
    }
    Write-Host "`nAll checks passed."
} finally {
    Pop-Location
}
