# Installs the pinned gdUnit4 version into game/addons/gdUnit4 (gitignored).
# PowerShell counterpart of install_gdunit4.sh. Needs git on PATH.
$ErrorActionPreference = 'Stop'

$Version = 'v6.2.2'
if ($env:GDUNIT4_VERSION) { $Version = $env:GDUNIT4_VERSION }
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root 'game/addons/gdUnit4'
$PluginCfg = Join-Path $Dest 'plugin.cfg'

$Wanted = "version=`"$($Version.TrimStart('v'))`""
if ((Test-Path $PluginCfg) -and (Select-String -Path $PluginCfg -SimpleMatch $Wanted -Quiet)) {
    Write-Host "gdUnit4 $Version already installed"
    return
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
try {
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch $Version `
        https://github.com/godot-gdunit-labs/gdUnit4.git (Join-Path $Tmp 'gdunit4')
    if ($LASTEXITCODE -ne 0) { throw "git clone of gdUnit4 $Version failed" }
    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
    Copy-Item -Recurse (Join-Path $Tmp 'gdunit4/addons/gdUnit4') $Dest
    # The addon ships its own test suite; we don't run it.
    Remove-Item -Recurse -Force (Join-Path $Dest 'test')
    Write-Host "gdUnit4 $Version installed to $Dest"
} finally {
    if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
}
