# Headless network test: for every scenario in game/tests/scenarios, starts a host and a client
# Godot over ENet on localhost (game/tools/net_test.gd), plays the scenario as co-op and fails
# on any per-wave state hash mismatch, failed host command on the client, or timeout.
# PowerShell counterpart of run_network_test.sh.
# Usage: .\tools\run_network_test.ps1 [scenario.json ...]   (names inside game/tests/scenarios)
# Set $env:GODOT_BIN to use your own binary; it must match .godot-version.
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1') }

Push-Location (Join-Path $Root 'game')
try {
    # Import once so class_name scripts and resources are registered.
    & $Godot --headless --import 2>&1 | Out-Null

    $Scenarios = @($args)
    if ($Scenarios.Count -eq 0) {
        $Scenarios = @(Get-ChildItem 'tests/scenarios/*.json' | ForEach-Object { $_.Name })
    }
    $Logs = Join-Path ([IO.Path]::GetTempPath()) ("two-wards-net-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $Logs | Out-Null
    $Port = 17777
    $Failed = 0
    foreach ($Name in $Scenarios) {
        $Port++
        $Common = @('--headless', '--path', '.', '--script', 'res://tools/net_test.gd', '--',
            "--port=$Port", "--scenario=res://tests/scenarios/$Name")
        $HostLog = Join-Path $Logs 'host.log'
        $ClientLog = Join-Path $Logs 'client.log'
        $HostProc = Start-Process -FilePath $Godot -ArgumentList ($Common + '--role=host') `
            -RedirectStandardOutput $HostLog -RedirectStandardError "$HostLog.err" `
            -NoNewWindow -PassThru
        $ClientProc = Start-Process -FilePath $Godot -ArgumentList ($Common + '--role=client') `
            -RedirectStandardOutput $ClientLog -RedirectStandardError "$ClientLog.err" `
            -NoNewWindow -PassThru
        $ClientProc.WaitForExit()
        $HostProc.WaitForExit()
        $Lines = @(Get-Content $HostLog, $ClientLog | Where-Object {
                $_ -match '^\[(host|client) ' -and $_ -notmatch ' (skipped|refused) '
            })
        $Lines | ForEach-Object { Write-Host $_ }
        if ($HostProc.ExitCode -ne 0 -or $ClientProc.ExitCode -ne 0) {
            Write-Host "FAILED $Name (host exit $($HostProc.ExitCode), client exit $($ClientProc.ExitCode))"
            Get-Content $HostLog, $ClientLog, "$HostLog.err", "$ClientLog.err" |
                Where-Object { $_ -match 'ERROR|desync' } | Select-Object -First 20 |
                ForEach-Object { Write-Host $_ }
            $Failed++
        } else {
            Write-Host "ok $Name"
        }
    }
    Remove-Item -Recurse -Force $Logs
} finally {
    Pop-Location
}

if ($Failed -gt 0) {
    Write-Host "$Failed of $($Scenarios.Count) network scenario(s) failed"
    exit 1
}
Write-Host "All $($Scenarios.Count) network scenarios in sync."
exit 0
