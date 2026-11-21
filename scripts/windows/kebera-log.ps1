# =============================================================================
#  KEBERA IS NOT A HACKING TOOL. It only pings your own router, the next private
#  hop after it (found automatically) and two fixed public test servers. There is
#  deliberately no option to choose other targets. Misuse is not tolerated.
#  See ACCEPTABLE_USE.md.
# =============================================================================
<#
.SYNOPSIS
    Kebera long logger: records your connection every few seconds for hours,
    so problems that come and go can be caught in the act.

.DESCRIPTION
    Every few seconds it pings, at the same moment:
      - your router
      - the next device after it (outdoor unit / fibre modem / provider), if there is one
      - Google (8.8.8.8) and Cloudflare (1.1.1.1)
    and notes this computer's Wi-Fi signal. Results go to a CSV file.
    When it finishes, it runs kebera-analyze-log.ps1 automatically.

    Read-only. Keep the computer plugged in and awake while it runs.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera-log.ps1 -Hours 3
#>
[CmdletBinding()]
param(
    [double]$Hours = 3,
    [int]$IntervalSec = 5,
    [string]$OutFile
)

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $OutFile) {
    $dir = Join-Path $RepoRoot 'reports'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $OutFile = Join-Path $dir ('kebera-log_' + (Get-Date -Format 'yyyy-MM-dd_HHmm') + '.csv')
}

function Test-PrivateIP([string]$ip) {
    if (-not $ip -or $ip -notmatch '^\d+\.\d+\.\d+\.\d+$') { return $false }
    $o = $ip.Split('.') | ForEach-Object { [int]$_ }
    return (($o[0] -eq 10) -or ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) -or ($o[0] -eq 192 -and $o[1] -eq 168) -or ($o[0] -eq 100 -and $o[1] -ge 64 -and $o[1] -le 127))
}

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
if (-not $cfg) { Write-Host 'No active connection found.' -ForegroundColor Red; exit 1 }
$gateway = (@($cfg.IPv4DefaultGateway)[0]).NextHop

$upstream = ''
$tr = tracert -d -h 2 -w 800 8.8.8.8 2>$null
foreach ($l in $tr) { if ($l -match '^\s*2\s+.*?(\d+\.\d+\.\d+\.\d+)\s*$') { if ((Test-PrivateIP $Matches[1]) -and $Matches[1] -ne $gateway) { $upstream = $Matches[1] } } }

$targets = [ordered]@{ router = $gateway }
if ($upstream) { $targets['upstream'] = $upstream }
$targets['google'] = '8.8.8.8'
$targets['cloudflare'] = '1.1.1.1'

if (-not (Test-Path $OutFile)) {
    'time,router_ms,upstream_ms,google_ms,cloudflare_ms,wifi_signal,wifi_band' | Out-File -Encoding utf8 $OutFile
}

$end = (Get-Date).AddHours($Hours)
Write-Host "Kebera logger: every $IntervalSec s until $($end.ToString('HH:mm')) -> $OutFile" -ForegroundColor Green
Write-Host "Router $gateway$(if ($upstream) { ", next device $upstream" }). Keep this window open and the computer awake. Ctrl+C stops early (data so far is kept)."

while ((Get-Date) -lt $end) {
    $start = Get-Date
    $tasks = [ordered]@{}
    foreach ($k in $targets.Keys) { $tasks[$k] = (New-Object System.Net.NetworkInformation.Ping).SendPingAsync($targets[$k], 2000) }
    $vals = @{}
    foreach ($k in @($tasks.Keys)) {
        $v = 'LOST'
        try { $r = $tasks[$k].Result; if ($r.Status -eq 'Success') { $v = [string]$r.RoundtripTime } } catch { }
        $vals[$k] = $v
    }
    $up = ''; if ($upstream) { $up = $vals['upstream'] }
    $sig = ''; $band = ''
    $wl = netsh wlan show interfaces 2>$null
    if ($wl) {
        $m = $wl | Select-String '^\s*Signal\s*:\s*(\d+)%' | Select-Object -First 1
        if ($m) { $sig = $m.Matches[0].Groups[1].Value }
        $b = $wl | Select-String '^\s*Band\s*:\s*(.+)$' | Select-Object -First 1
        if ($b) { $band = $b.Matches[0].Groups[1].Value.Trim() }
    }
    "$($start.ToString('yyyy-MM-dd HH:mm:ss')),$($vals['router']),$up,$($vals['google']),$($vals['cloudflare']),$sig,$band" | Out-File -Append -Encoding utf8 $OutFile
    $wait = $IntervalSec - ((Get-Date) - $start).TotalSeconds
    if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]($wait * 1000)) }
}

Write-Host 'Logging finished. Analysing...' -ForegroundColor Green
& (Join-Path $PSScriptRoot 'kebera-analyze-log.ps1') -LogFile $OutFile
