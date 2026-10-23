# Headless network test: for every scenario in game/tests/scenarios, starts a host and a client
# Godot over ENet on localhost (game/tools/net_test.gd), plays the scenario as co-op and fails
# on any per-wave state hash mismatch, failed host command on the client, or timeout. Then plays
# one co-op scenario over WebRTC through a local lobby (lobby/, needs bun; skipped without bun
# except in CI).
# PowerShell counterpart of run_network_test.sh.
# Usage: .\tools\run_network_test.ps1 [scenario.json ...]   (names inside game/tests/scenarios)
# Set $env:GODOT_BIN to use your own binary; it must match .godot-version.
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$WebRtcScenario = 'coop_two_wizards_pass_cards.json'
$LobbyPort = 18900
$Godot = $env:GODOT_BIN
if (-not $Godot) { $Godot = & (Join-Path $PSScriptRoot 'install_godot.ps1') }

Push-Location (Join-Path $Root 'game')
try {
    # Import once so class_name scripts and resources are registered.
    & { $ErrorActionPreference = 'Continue'; & $Godot --headless --import 2>&1 | Out-Null }

    $Scenarios = @($args)
    if ($Scenarios.Count -eq 0) {
        $Scenarios = @(Get-ChildItem 'tests/scenarios/*.json' | ForEach-Object { $_.Name })
    }
    $Logs = Join-Path ([IO.Path]::GetTempPath()) ("two-wards-net-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $Logs | Out-Null
    $HostLog = Join-Path $Logs 'host.log'
    $ClientLog = Join-Path $Logs 'client.log'
    $Port = 17777
    $Runs = 0
    $Failed = 0

    function Start-NetTest($Log, [string[]]$TestArgs) {
        $Common = @('--headless', '--path', '.', '--script', 'res://tools/net_test.gd', '--')
        $Proc = Start-Process -FilePath $Godot -ArgumentList ($Common + $TestArgs) `
            -RedirectStandardOutput $Log -RedirectStandardError "$Log.err" -NoNewWindow -PassThru
        # PS 5.1 leaves ExitCode empty unless the handle was read while the process ran.
        $null = $Proc.Handle
        return $Proc
    }

    # Prints the outcome of one host + client pair and counts failures.
    function Write-Result($Label, $HostProc, $ClientProc) {
        $script:Runs++
        $Lines = @(Get-Content $HostLog, $ClientLog | Where-Object {
                $_ -match '^\[(host|client) ' -and $_ -notmatch ' (skipped|refused) '
            })
        $Lines | ForEach-Object { Write-Host $_ }
        if ($HostProc.ExitCode -ne 0 -or $ClientProc.ExitCode -ne 0) {
            Write-Host "FAILED $Label (host exit $($HostProc.ExitCode), client exit $($ClientProc.ExitCode))"
            Get-Content $HostLog, $ClientLog, "$HostLog.err", "$ClientLog.err" |
                Where-Object { $_ -match 'ERROR|desync' } | Select-Object -First 20 |
                ForEach-Object { Write-Host $_ }
            $script:Failed++
        } else {
            Write-Host "ok $Label"
        }
    }

    foreach ($Name in $Scenarios) {
        $Port++
        $Common = @("--port=$Port", "--scenario=res://tests/scenarios/$Name")
        $HostProc = Start-NetTest $HostLog ($Common + '--role=host')
        $ClientProc = Start-NetTest $ClientLog ($Common + '--role=client')
        $ClientProc.WaitForExit()
        $HostProc.WaitForExit()
        Write-Result $Name $HostProc $ClientProc
    }

    $Bun = Get-Command bun -ErrorAction SilentlyContinue
    if (-not $Bun) {
        if ($env:CI) { throw 'bun is required for the WebRTC network test' }
        Write-Host 'skipped WebRTC: install bun (https://bun.sh) to run it'
    } else {
        $env:PORT = $LobbyPort
        $Lobby = Start-Process -FilePath $Bun.Source -ArgumentList (Join-Path $Root 'lobby/src/server.ts') `
            -RedirectStandardOutput (Join-Path $Logs 'lobby.log') `
            -RedirectStandardError (Join-Path $Logs 'lobby.err') -NoNewWindow -PassThru
        Remove-Item Env:PORT
        try {
            $LobbyUrl = "ws://127.0.0.1:$LobbyPort/ws"
            foreach ($i in 1..50) {
                try {
                    $null = Invoke-WebRequest "http://127.0.0.1:$LobbyPort/healthz" -UseBasicParsing
                    break
                } catch { Start-Sleep -Milliseconds 200 }
            }
            $Common = @("--lobby=$LobbyUrl", "--scenario=res://tests/scenarios/$WebRtcScenario")
            $HostProc = Start-NetTest $HostLog ($Common + '--role=host')
            $Code = ''
            foreach ($i in 1..100) {
                $Found = Select-String -Path $HostLog -Pattern 'room ([A-Z]{4})' -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($Found) { $Code = $Found.Matches[0].Groups[1].Value; break }
                Start-Sleep -Milliseconds 200
            }
            $ClientProc = Start-NetTest $ClientLog ($Common + '--role=client' + "--code=$Code")
            $ClientProc.WaitForExit()
            $HostProc.WaitForExit()
            Write-Result "$WebRtcScenario (WebRTC)" $HostProc $ClientProc
        } finally {
            Stop-Process -Id $Lobby.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -Recurse -Force $Logs
} finally {
    Pop-Location
}

if ($Failed -gt 0) {
    Write-Host "$Failed of $Runs network run(s) failed"
    exit 1
}
Write-Host "All $Runs network runs in sync."
exit 0
