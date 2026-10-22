# Downloads the Godot version pinned in .godot-version into .tools/godot/<version>/
# (gitignored), verifies it against tools/godot-<version>.sha512, and returns the
# binary path. Re-running is a no-op once installed.
# PowerShell counterpart of install_godot.sh; works on Windows PowerShell 5.1 and pwsh 7.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content (Join-Path $Root '.godot-version') -Raw).Trim()
$Sums = Join-Path $Root "tools/godot-$Version.sha512"
$Dest = Join-Path $Root ".tools/godot/$Version"

# $IsWindows is not defined on Windows PowerShell 5.1, which only runs on Windows.
if ($PSVersionTable.PSEdition -ne 'Core' -or $IsWindows) {
    $Asset = 'win64.exe'
    $Bin = "Godot_v$Version-stable_win64_console.exe"
} elseif ($IsMacOS) {
    $Asset = 'macos.universal'
    $Bin = 'Godot.app/Contents/MacOS/Godot'
} else {
    $Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($Arch -eq 'Arm64') { $Asset = 'linux.arm64' } else { $Asset = 'linux.x86_64' }
    $Bin = "Godot_v$Version-stable_$Asset"
}

$BinPath = Join-Path $Dest $Bin
if (Test-Path $BinPath) {
    return $BinPath
}

if (-not (Test-Path $Sums)) {
    throw "Missing $Sums. Add the SHA512 lines for Godot $Version from its release's SHA512-SUMS.txt."
}

$Zip = "Godot_v$Version-stable_$Asset.zip"
$Expected = $null
foreach ($Line in Get-Content $Sums) {
    $Parts = $Line -split '\s+'
    if ($Parts.Count -ge 2 -and $Parts[1] -eq $Zip) { $Expected = $Parts[0] }
}
if (-not $Expected) {
    throw "No checksum for $Zip in $Sums"
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
    $ZipPath = Join-Path $Tmp $Zip
    Write-Host "Downloading Godot $Version ($Asset)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Url = "https://github.com/godotengine/godot/releases/download/$Version-stable/$Zip"
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing

    $Actual = (Get-FileHash -Algorithm SHA512 -Path $ZipPath).Hash.ToLower()
    if ($Actual -ne $Expected.ToLower()) {
        throw "Checksum mismatch for $Zip"
    }

    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Expand-Archive -Path $ZipPath -DestinationPath $Dest -Force
    if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
        chmod +x $BinPath
    }
    Write-Host "Installed Godot $Version to $Dest"
} finally {
    Remove-Item -Recurse -Force $Tmp
}
return $BinPath
