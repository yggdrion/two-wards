# Installs the Linux and Windows release export templates for the Godot version
# pinned in .godot-version, verified against tools/godot-<version>.sha512, into
# the directory Godot reads templates from, and returns that directory.
# Only the two templates we ship are extracted; the full .tpz is ~1.3 GB.
# PowerShell counterpart of install_godot_templates.sh. Re-running is a no-op once installed.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Root = Split-Path -Parent $PSScriptRoot
$Version = (Get-Content (Join-Path $Root '.godot-version') -Raw).Trim()
$Sums = Join-Path $Root "tools/godot-$Version.sha512"
$Files = @('version.txt', 'linux_release.x86_64', 'windows_release_x86_64.exe')

# $IsWindows is not defined on Windows PowerShell 5.1, which only runs on Windows.
if ($PSVersionTable.PSEdition -ne 'Core' -or $IsWindows) {
    $Data = Join-Path $env:APPDATA 'Godot'
} elseif ($IsMacOS) {
    $Data = Join-Path $HOME 'Library/Application Support/Godot'
} else {
    $XdgData = $env:XDG_DATA_HOME
    if (-not $XdgData) { $XdgData = Join-Path $HOME '.local/share' }
    $Data = Join-Path $XdgData 'godot'
}
$Dest = Join-Path $Data "export_templates/$Version.stable"

$Missing = $Files | Where-Object { -not (Test-Path (Join-Path $Dest $_)) }
if (-not $Missing) {
    return $Dest
}

$Tpz = "Godot_v$Version-stable_export_templates.tpz"
$Expected = $null
if (Test-Path $Sums) {
    foreach ($Line in Get-Content $Sums) {
        $Parts = $Line -split '\s+'
        if ($Parts.Count -ge 2 -and $Parts[1] -eq $Tpz) { $Expected = $Parts[0] }
    }
}
if (-not $Expected) {
    throw "No checksum for $Tpz in $Sums. Add its line from the release's SHA512-SUMS.txt."
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
    $TpzPath = Join-Path $Tmp $Tpz
    Write-Host "Downloading Godot $Version export templates (~1.3 GB)..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Url = "https://github.com/godotengine/godot/releases/download/$Version-stable/$Tpz"
    Invoke-WebRequest -Uri $Url -OutFile $TpzPath -UseBasicParsing

    $Actual = (Get-FileHash -Algorithm SHA512 -Path $TpzPath).Hash.ToLower()
    if ($Actual -ne $Expected.ToLower()) {
        throw "Checksum mismatch for $Tpz"
    }

    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Zip = [System.IO.Compression.ZipFile]::OpenRead($TpzPath)
    try {
        foreach ($File in $Files) {
            $Entry = $Zip.GetEntry("templates/$File")
            if (-not $Entry) { throw "templates/$File not found in $Tpz" }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($Entry, (Join-Path $Dest $File), $true)
        }
    } finally {
        $Zip.Dispose()
    }
    Write-Host "Installed Godot $Version export templates to $Dest"
} finally {
    Remove-Item -Recurse -Force $Tmp
}
return $Dest
