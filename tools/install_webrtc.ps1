# Installs the pinned webrtc-native GDExtension (WebRTC for desktop Godot) into
# game/addons/webrtc_native (gitignored) and checks its sha256. install_godot.ps1 runs this,
# so every script that uses the pinned Godot has it.
# PowerShell counterpart of install_webrtc.sh.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Version = '1.2.2-stable'
$Sha256 = '98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5'
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root 'game/addons/webrtc_native'
$Marker = Join-Path $Dest '.version'

if ((Test-Path $Marker) -and ((Get-Content $Marker -Raw).Trim() -eq $Version)) {
    return
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $Tmp | Out-Null
try {
    $ZipPath = Join-Path $Tmp 'webrtc.zip'
    Write-Host "Downloading webrtc-native $Version..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Url = "https://github.com/godotengine/webrtc-native/releases/download/$Version/godot-extension-webrtc_native.zip"
    Invoke-WebRequest -Uri $Url -OutFile $ZipPath -UseBasicParsing
    if ((Get-FileHash -Algorithm SHA256 -Path $ZipPath).Hash.ToLower() -ne $Sha256) {
        throw "Checksum mismatch for webrtc-native $Version"
    }
    Expand-Archive -Path $ZipPath -DestinationPath (Join-Path $Tmp 'x') -Force
    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dest) | Out-Null
    Move-Item (Join-Path $Tmp 'x/addons/webrtc_native') $Dest
    Set-Content -Path $Marker -Value $Version -Encoding ascii
    Write-Host "webrtc-native $Version installed to $Dest"
} finally {
    Remove-Item -Recurse -Force $Tmp
}
