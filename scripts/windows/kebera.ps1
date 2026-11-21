<#
.SYNOPSIS
    Kebera: a read-only home internet check-up for Windows.

.DESCRIPTION
    Runs standard network tests (Wi-Fi status, nearby networks, ping, traceroute,
    DNS speed and an optional speed test), tries to identify your router, outdoor
    unit or fibre modem from the normal web pages they already show, and writes a
    plain-language report saying WHERE the problem most likely is:

        this computer  ->  your Wi-Fi  ->  your router  ->  outdoor unit / modem  ->  your provider

    Kebera never changes settings, never logs in to anything and never guesses
    passwords. It only sends the same kind of requests your browser sends when you
    open your router's page. See DISCLAIMER.md and PRIVACY.md.

.PARAMETER Quick
    Shorter test (about 2 minutes). Less reliable for problems that come and go.

.PARAMETER NoSpeedTest
    Skip the download/upload test (saves about 35 MB of data, 12 MB in -Quick mode).

.PARAMETER NoInternetServices
    Skip everything that contacts outside services apart from pings and DNS:
    no public IP lookup and no speed test.

.PARAMETER PingRounds
    How many rounds of pings to send (one round every 0.5 s). Default 120, or 40 with -Quick.

.PARAMETER OutDir
    Where to save the report. Default: reports\<date_time> inside the Kebera folder.

.PARAMETER NoOpen
    Do not open the HTML report when finished.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera.ps1 -Quick -NoSpeedTest
#>
[CmdletBinding()]
param(
    [switch]$Quick,
    [switch]$NoSpeedTest,
    [switch]$NoInternetServices,
    [int]$PingRounds = 0,
    [string]$OutDir,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$KeberaVersion = '0.1.0'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

if ($PingRounds -le 0) { if ($Quick) { $PingRounds = 40 } else { $PingRounds = 120 } }
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot ('reports\' + (Get-Date -Format 'yyyy-MM-dd_HHmm')) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$msg) { Write-Host ''; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Note([string]$msg) { Write-Host "    $msg" -ForegroundColor Gray }

function Test-PrivateIP([string]$ip) {
    if (-not $ip -or $ip -notmatch '^\d+\.\d+\.\d+\.\d+$') { return $false }
    $o = $ip.Split('.') | ForEach-Object { [int]$_ }
    return (($o[0] -eq 10) -or
            ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) -or
            ($o[0] -eq 192 -and $o[1] -eq 168) -or
            ($o[0] -eq 100 -and $o[1] -ge 64 -and $o[1] -le 127))
}

function Get-Num($text) {
    if ($null -eq $text) { return $null }
    $m = [regex]::Match([string]$text, '-?\d+(\.\d+)?')
    if ($m.Success) { return [double]$m.Value }
    return $null
}

function Hide-Ssid([string]$ssid) {
    if (-not $ssid -or $ssid -eq '(hidden)') { return '(hidden)' }
    if ($ssid.Length -le 2) { return '**' }
    return $ssid.Substring(0, 2) + ('*' * [math]::Min(6, $ssid.Length - 2))
}

function Invoke-Get([string]$url, [hashtable]$headers = @{}, [int]$timeout = 6) {
    try {
        $r = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec $timeout -MaximumRedirection 3 -ErrorAction Stop
        $final = $url
        try { $final = $r.BaseResponse.ResponseUri.AbsoluteUri } catch { }
        return [ordered]@{ ok = $true; url = $final; status = [int]$r.StatusCode; server = [string]$r.Headers['Server']; body = [string]$r.Content }
    } catch {
        return [ordered]@{ ok = $false; url = $url; error = $_.Exception.Message }
    }
}

function New-Finding([string]$area, [string]$severity, [string]$title, [string]$detail, [string]$fix) {
    return [ordered]@{ area = $area; severity = $severity; title = $title; detail = $detail; fix = $fix }
}

# ---------------------------------------------------------------------------
# 1. How is this computer connected?
# ---------------------------------------------------------------------------

function Get-NetBasics {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
        Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
        Select-Object -First 1
    if (-not $cfg) { return $null }
    $ad = $cfg.NetAdapter
    $isWifi = ($ad.PhysicalMediaType -match '802\.11') -or ($ad.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN|802\.11')
    $conn = 'Wired'
    if ($isWifi) { $conn = 'Wi-Fi' }
    $dns = @()
    foreach ($d in @($cfg.DNSServer)) { if ($d.AddressFamily -eq 2) { $dns += $d.ServerAddresses } }
    return [ordered]@{
        adapter     = $cfg.InterfaceAlias
        description = $ad.InterfaceDescription
        connection  = $conn
        linkSpeed   = [string]$ad.LinkSpeed
        ipv4        = (@($cfg.IPv4Address)[0]).IPAddress
        gateway     = (@($cfg.IPv4DefaultGateway)[0]).NextHop
        dns         = @($dns | Select-Object -Unique)
    }
}

# Note: netsh output is in the Windows display language. These parsers expect English.
function Get-WifiInfo {
    $out = netsh wlan show interfaces 2>$null
    if (-not $out) { return $null }
    $h = @{}
    foreach ($l in $out) {
        if ($l -match '^\s{2,}([^:]+?)\s*:\s(.*)$') {
            $k = $Matches[1].Trim(); $v = $Matches[2].Trim()
            if (-not $h.ContainsKey($k)) { $h[$k] = $v }
        }
    }
    if ($h['State'] -ne 'connected') { return [ordered]@{ state = [string]$h['State'] } }
    $ch = [int](Get-Num $h['Channel'])
    $band = [string]$h['Band']
    if (-not $band) { if ($ch -gt 14) { $band = '5 GHz' } elseif ($ch -gt 0) { $band = '2.4 GHz' } }
    return [ordered]@{
        state     = 'connected'
        ssid      = [string]$h['SSID']
        bssid     = [string]$h['BSSID']
        radio     = [string]$h['Radio type']
        band      = $band
        channel   = $ch
        signalPct = [int](Get-Num $h['Signal'])
        rxMbps    = Get-Num $h['Receive rate (Mbps)']
        txMbps    = Get-Num $h['Transmit rate (Mbps)']
        security  = [string]$h['Authentication']
    }
}

function Request-WifiScan {
    # Windows keeps an old list of nearby networks. Ask the Wi-Fi adapter for a fresh scan
    # (the same thing that happens when you open the Wi-Fi menu), then wait for it to finish.
    try {
        $guidLine = netsh wlan show interfaces 2>$null | Select-String '^\s+GUID\s*:\s*([0-9a-fA-F-]{36})' | Select-Object -First 1
        if (-not $guidLine) { return }
        $guid = [Guid]$guidLine.Matches[0].Groups[1].Value
        if (-not ('KeberaWlan' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class KeberaWlan {
    [DllImport("wlanapi.dll")] static extern uint WlanOpenHandle(uint ver, IntPtr res, out uint neg, out IntPtr h);
    [DllImport("wlanapi.dll")] static extern uint WlanScan(IntPtr h, ref Guid g, IntPtr ssid, IntPtr ie, IntPtr res);
    [DllImport("wlanapi.dll")] static extern uint WlanCloseHandle(IntPtr h, IntPtr res);
    public static uint Scan(Guid g) {
        uint neg; IntPtr h;
        uint rc = WlanOpenHandle(2, IntPtr.Zero, out neg, out h);
        if (rc != 0) return rc;
        rc = WlanScan(h, ref g, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero);
        WlanCloseHandle(h, IntPtr.Zero);
        return rc;
    }
}
'@ -ErrorAction Stop
        }
        if ([KeberaWlan]::Scan($guid) -eq 0) { Start-Sleep -Seconds 5 }
    } catch { }
}

function Get-WifiScan {
    Request-WifiScan
    $out = netsh wlan show networks mode=bssid 2>$null
    $list = New-Object System.Collections.ArrayList
    $ssid = ''; $cur = $null
    foreach ($l in $out) {
        if ($l -match '^SSID \d+ :\s?(.*)$') { $ssid = $Matches[1].Trim(); if (-not $ssid) { $ssid = '(hidden)' }; $cur = $null; continue }
        if ($l -match '^\s+BSSID \d+\s*:\s*(\S+)') {
            $cur = [ordered]@{ ssid = $ssid; bssid = $Matches[1]; signalPct = 0; band = ''; channel = 0; radio = ''; stations = $null; utilizationPct = $null }
            [void]$list.Add($cur); continue
        }
        if (-not $cur) { continue }
        if ($l -match '^\s+Signal\s*:\s*(\d+)%') { $cur.signalPct = [int]$Matches[1] }
        elseif ($l -match '^\s+Radio type\s*:\s*(.+)$') { $cur.radio = $Matches[1].Trim() }
        elseif ($l -match '^\s+Band\s*:\s*(.+)$') { $cur.band = $Matches[1].Trim() }
        elseif ($l -match '^\s+Channel\s*:\s*(\d+)') { $cur.channel = [int]$Matches[1] }
        elseif ($l -match 'Connected Stations:\s+(\d+)') { $cur.stations = [int]$Matches[1] }
        elseif ($l -match 'Channel Utilization:\s+\d+\s+\((\d+)\s?%\)') { $cur.utilizationPct = [int]$Matches[1] }
    }
    foreach ($n in $list) {
        if (-not $n.band) { if ($n.channel -gt 14) { $n.band = '5 GHz' } elseif ($n.channel -gt 0) { $n.band = '2.4 GHz' } }
    }
    return ,$list
}

function Get-WifiCrowding($wifi, $scan) {
    if (-not $wifi -or $wifi.state -ne 'connected' -or -not $wifi.channel) { return $null }
    $ch = [int]$wifi.channel
    $own = [string]$wifi.ssid
    $isOwn = { param($n) $own -and $n.ssid -and $n.ssid.StartsWith($own) }
    $foreign = @($scan | Where-Object { -not (& $isOwn $_) })
    $is24 = $ch -le 14
    if ($is24) { $overlap = @($foreign | Where-Object { $_.channel -ge 1 -and $_.channel -le 14 -and [math]::Abs($_.channel - $ch) -le 4 }) }
    else { $overlap = @($foreign | Where-Object { $_.channel -eq $ch }) }
    $strong = @($overlap | Where-Object { $_.signalPct -ge 50 })

    $best = $null
    if ($is24) {
        $scores = @{}
        foreach ($c in 1, 6, 11) {
            $sum = (@($foreign | Where-Object { $_.channel -ge 1 -and $_.channel -le 14 -and [math]::Abs($_.channel - $c) -le 4 } | ForEach-Object { $_.signalPct }) | Measure-Object -Sum).Sum
            if ($null -eq $sum) { $sum = 0 }
            $scores[$c] = $sum
        }
        $best = ($scores.GetEnumerator() | Sort-Object Value, Name | Select-Object -First 1).Key
    }
    $own5 = @($scan | Where-Object { (& $isOwn $_) -and $_.channel -gt 14 } | Sort-Object { $_.signalPct } -Descending | Select-Object -First 1)
    $mine = @($scan | Where-Object { $_.bssid -eq $wifi.bssid } | Select-Object -First 1)
    $bandName = '5 GHz'; if ($is24) { $bandName = '2.4 GHz' }
    $own5Signal = $null; $own5Name = $null
    if ($own5.Count -gt 0) { $own5Signal = $own5[0].signalPct; $own5Name = $own5[0].ssid }
    $util = $null; if ($mine.Count -gt 0) { $util = $mine[0].utilizationPct }
    return [ordered]@{
        channel            = $ch
        band               = $bandName
        networksVisible    = @($scan).Count
        overlapping        = $overlap.Count
        strongOverlapping  = $strong.Count
        suggested24Channel = $best
        own5GHzVisible     = ($own5.Count -gt 0)
        own5GHzName        = $own5Name
        own5GHzSignalPct   = $own5Signal
        ownUtilizationPct  = $util
    }
}

# ---------------------------------------------------------------------------
# 2. Route to the internet
# ---------------------------------------------------------------------------

function Get-Trace([string]$target = '8.8.8.8') {
    $out = tracert -d -h 15 -w 800 $target 2>$null
    $hops = New-Object System.Collections.ArrayList
    foreach ($l in $out) {
        if ($l -match '^\s*(\d+)\s+(.*)$') {
            $n = [int]$Matches[1]; $rest = $Matches[2]
            $times = @()
            foreach ($m in [regex]::Matches($rest, '(<?\d+)\s*ms|\*')) {
                if ($m.Value -eq '*') { $times += $null } else { $times += [int]($m.Groups[1].Value -replace '<', '') }
            }
            $ip = $null
            if ($rest -match '(\d+\.\d+\.\d+\.\d+)\s*$') { $ip = $Matches[1] }
            [void]$hops.Add([ordered]@{ hop = $n; ip = $ip; timesMs = $times; private = (Test-PrivateIP $ip) })
        }
    }
    return ,$hops
}

# ---------------------------------------------------------------------------
# 3. Identify equipment (read-only, no login)
# ---------------------------------------------------------------------------

$VendorPatterns = [ordered]@{
    'ZTE'       = '\bzte\b|logo_zte|goform_get_cmd_process'
    'Huawei'    = 'huawei|hilink|echolife|/api/webserver'
    'TP-Link'   = 'tp-?link|tplinkwifi'
    'Tenda'     = '\btenda\b'
    'MikroTik'  = 'mikrotik|routeros|webfig'
    'Nokia'     = '\bnokia\b'
    'FiberHome' = 'fiberhome'
    'D-Link'    = 'd-link|\bdlink\b'
    'Netgear'   = 'netgear'
    'Ubiquiti'  = 'ubiquiti|\bubnt\b|\bunifi\b|\bairos\b'
    'Cambium'   = 'cambium'
    'Mercusys'  = 'mercusys'
    'Alcatel'   = 'alcatel'
    'Starlink'  = 'starlink'
}
$ProviderPatterns = [ordered]@{
    'Airtel'   = 'airtel'
    'MTN'      = '\bmtn\b'
    'Lyca'     = 'lycamobile|\blyca\b'
    'Roke'     = 'roke ?telkom|\broke\b'
    'Starlink' = 'starlink'
}
$RolePatterns = [ordered]@{
    'Outdoor 4G/5G unit (ODU)'       = 'outdoor cpe|outdoor unit|\bodu\b'
    'Indoor router (CPE)'            = 'indoor cpe|\bidu\b'
    'Fibre modem (ONT)'              = '\bont\b|\bgpon\b|\bxpon\b|\bepon\b'
    'Mobile hotspot (MiFi)'          = '\bmifi\b|pocket wi-?fi|mobile wi-?fi'
}

function Invoke-ZteProbe([string]$base) {
    $fields = 'model_name,cr_version,hardware_version,wa_inner_version,network_type,network_provider,signalbar,rssi,rsrp,rsrq,sinr,lte_band,Z5g_rsrp,Z5g_sinr,Z5g_rsrq,nr5g_action_band,wan_ipaddr,ppp_status,modem_main_state'
    $r = Invoke-Get ($base + "goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=$fields") @{ Referer = ($base + 'index.html') } 5
    if (-not $r.ok -or $r.body -notmatch '^\s*\{') { return $null }
    try { $j = $r.body | ConvertFrom-Json } catch { return $null }
    $o = [ordered]@{ _api = 'zte' }
    foreach ($p in $j.PSObject.Properties) { if (("$($p.Value)").Trim() -ne '') { $o[$p.Name] = "$($p.Value)" } }
    # Many ZTE units report these placeholder values when nobody is logged in. Drop them to avoid false alarms.
    foreach ($k in @('modem_main_state', 'ppp_status')) { if ($o.Contains($k)) { $o.Remove($k) } }
    return $o
}

function Invoke-HuaweiProbe([string]$base) {
    # The anonymous session token below is what the router's own web page requests before you log in.
    $tok = Invoke-Get ($base + 'api/webserver/SesTokInfo') @{} 5
    $h = @{}
    $isHuawei = $false
    if ($tok.ok -and $tok.body -match '<SesInfo>([^<]*)</SesInfo>') {
        $isHuawei = $true
        $h['Cookie'] = $Matches[1]
        if ($tok.body -match '<TokInfo>([^<]*)</TokInfo>') { $h['__RequestVerificationToken'] = $Matches[1] }
    }
    $o = [ordered]@{}
    foreach ($ep in 'api/device/basic_information', 'api/device/signal', 'api/monitoring/status', 'api/net/current-plmn') {
        $r = Invoke-Get ($base + $ep) $h 5
        if ($r.ok -and $r.body -match '<response>') {
            $isHuawei = $true
            foreach ($m in [regex]::Matches($r.body, '<(\w+)>([^<]+)</\1>')) {
                $key = $m.Groups[1].Value
                # Never keep identifiers: IMEI, IMSI, ICCID, serial numbers, MAC addresses, phone numbers.
                if ($key -match 'imei|imsi|iccid|serial|mac|msisdn|phone|number|uuid|esn|meid') { continue }
                $o[$key] = $m.Groups[2].Value
            }
        }
    }
    if (-not $isHuawei) { return $null }
    $o.Insert(0, '_api', 'huawei')
    return $o
}

function Get-DeviceFingerprint([string]$ip, [string]$label) {
    $dev = [ordered]@{ ip = $ip; label = $label; webPage = $false; vendor = $null; model = $null; provider = $null; role = $null; firmware = $null; wanIp = $null; evidence = @(); cellular = $null; raw = [ordered]@{} }
    $oldCb = [Net.ServicePointManager]::ServerCertificateValidationCallback
    # Home routers use self-signed certificates. Accept them ONLY for this local device check.
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    try {
        $page = $null
        foreach ($u in @("http://$ip/", "https://$ip/")) {
            $r = Invoke-Get $u @{} 5
            if ($r.ok) { $page = $r; break }
        }
        if (-not $page) {
            $dev.evidence += 'No web page answered. That is normal for provider network equipment.'
            return $dev
        }
        $dev.webPage = $true
        $base = ([uri]$page.url).GetLeftPart([UriPartial]::Authority) + '/'
        $text = $page.body + ' ' + $page.server
        if ($text -match '<title>\s*([^<]{1,80}?)\s*</title>') { $dev.raw['pageTitle'] = $Matches[1] }
        foreach ($v in $VendorPatterns.Keys) { if ($text -match $VendorPatterns[$v]) { $dev.vendor = $v; $dev.evidence += "Its web page mentions $v."; break } }
        foreach ($p in $ProviderPatterns.Keys) { if ($text -match $ProviderPatterns[$p]) { $dev.provider = $p; $dev.evidence += "Its web page is branded $p."; break } }
        foreach ($ro in $RolePatterns.Keys) { if ($text -match $RolePatterns[$ro]) { $dev.role = $ro; break } }

        $zte = Invoke-ZteProbe $base
        if ($zte) {
            $dev.vendor = 'ZTE'
            $dev.evidence += 'It answered the standard ZTE status interface.'
            if ($zte.Contains('model_name')) { $dev.model = $zte.model_name }
            if ($zte.Contains('cr_version')) { $dev.firmware = $zte.cr_version }
            elseif ($zte.Contains('wa_inner_version')) { $dev.firmware = $zte.wa_inner_version }
            if ($dev.firmware -match 'AIRTEL') { $dev.provider = 'Airtel' } elseif ($dev.firmware -match 'MTN') { $dev.provider = 'MTN' }
            if ($zte.Contains('wan_ipaddr')) { $dev.wanIp = $zte.wan_ipaddr }
            $cell = [ordered]@{}
            foreach ($k in 'network_type', 'network_provider', 'rsrp', 'rsrq', 'sinr', 'rssi', 'lte_band', 'Z5g_rsrp', 'Z5g_sinr', 'Z5g_rsrq', 'nr5g_action_band', 'signalbar') { if ($zte.Contains($k)) { $cell[$k] = $zte[$k] } }
            if ($cell.Count -gt 0) { $dev.cellular = $cell }
            $dev.raw['zte'] = $zte
        } else {
            $hw = Invoke-HuaweiProbe $base
            if ($hw) {
                $dev.vendor = 'Huawei'
                $dev.evidence += 'It answered the standard Huawei (HiLink) status interface.'
                foreach ($k in 'DeviceName', 'devicename') { if ($hw.Contains($k)) { $dev.model = $hw[$k] } }
                if ($hw.Contains('SoftwareVersion')) { $dev.firmware = $hw.SoftwareVersion }
                if ($hw.Contains('WanIPAddress')) { $dev.wanIp = $hw.WanIPAddress }
                if ($hw.Contains('FullName')) { if ($hw.FullName -match 'airtel') { $dev.provider = 'Airtel' } elseif ($hw.FullName -match 'mtn') { $dev.provider = 'MTN' } }
                $cell = [ordered]@{}
                foreach ($k in 'rsrp', 'rsrq', 'sinr', 'rssi', 'band', 'cell_id', 'CurrentNetworkType', 'SignalIcon', 'FullName') { if ($hw.Contains($k)) { $cell[$k] = $hw[$k] } }
                if ($cell.Count -gt 0) { $dev.cellular = $cell }
                $dev.raw['huawei'] = $hw
            }
        }
        if (-not $dev.role -and $dev.model) {
            if ($dev.model -match '^(MF|MC)\d') { $dev.role = 'Indoor router (CPE)' }
        }
    } finally {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCb
    }
    return $dev
}

# ---------------------------------------------------------------------------
# 4. Stability: ping several points at the same moment
# ---------------------------------------------------------------------------

function Measure-Targets($targets, [int]$rounds, [int]$intervalMs = 500) {
    $res = [ordered]@{}
    foreach ($k in $targets.Keys) { $res[$k] = New-Object System.Collections.ArrayList }
    for ($i = 0; $i -lt $rounds; $i++) {
        $start = Get-Date
        $tasks = [ordered]@{}
        foreach ($k in $targets.Keys) { $tasks[$k] = (New-Object System.Net.NetworkInformation.Ping).SendPingAsync($targets[$k], 1500) }
        foreach ($k in @($tasks.Keys)) {
            $v = $null
            try { $r = $tasks[$k].Result; if ($r.Status -eq 'Success') { $v = [int]$r.RoundtripTime } } catch { }
            [void]$res[$k].Add($v)
        }
        if ((($i + 1) % 20) -eq 0) { Write-Note ("{0}/{1} rounds done" -f ($i + 1), $rounds) }
        $wait = $intervalMs - ((Get-Date) - $start).TotalMilliseconds
        if ($wait -gt 0) { Start-Sleep -Milliseconds ([int]$wait) }
    }
    return $res
}

function Get-PingStats($samples) {
    $all = @($samples)
    $ok = @($all | Where-Object { $null -ne $_ })
    $sent = $all.Count; $recv = $ok.Count
    if ($recv -eq 0) { return [ordered]@{ sent = $sent; received = 0; lossPct = 100; minMs = $null; avgMs = $null; p95Ms = $null; maxMs = $null; jitterMs = $null; over150ms = 0 } }
    $sorted = @($ok | Sort-Object)
    $j = 0
    for ($i = 1; $i -lt $ok.Count; $i++) { $j += [math]::Abs($ok[$i] - $ok[$i - 1]) }
    $jit = 0; if ($ok.Count -gt 1) { $jit = [math]::Round($j / ($ok.Count - 1), 1) }
    $p95i = [math]::Min($sorted.Count - 1, [int][math]::Floor(0.95 * $sorted.Count))
    return [ordered]@{
        sent      = $sent
        received  = $recv
        lossPct   = [math]::Round(100.0 * ($sent - $recv) / $sent, 1)
        minMs     = $sorted[0]
        avgMs     = [math]::Round(($ok | Measure-Object -Average).Average, 1)
        p95Ms     = $sorted[$p95i]
        maxMs     = $sorted[-1]
        jitterMs  = $jit
        over150ms = @($ok | Where-Object { $_ -gt 150 }).Count
    }
}

# ---------------------------------------------------------------------------
# 5. DNS speed and internet speed
# ---------------------------------------------------------------------------

function Measure-Dns([string]$server, [string[]]$names) {
    $t = @(); $fail = 0
    foreach ($n in $names) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            Resolve-DnsName -Name $n -Server $server -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction Stop | Out-Null
            $sw.Stop(); $t += $sw.ElapsedMilliseconds
        } catch { $fail++ }
    }
    if ($t.Count -eq 0) { return [ordered]@{ server = $server; avgMs = $null; maxMs = $null; failed = $fail } }
    return [ordered]@{ server = $server; avgMs = [math]::Round(($t | Measure-Object -Average).Average); maxMs = ($t | Measure-Object -Maximum).Maximum; failed = $fail }
}

function Measure-Download([int]$bytes) {
    try {
        $wc = New-Object Net.WebClient
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $d = $wc.DownloadData("https://speed.cloudflare.com/__down?bytes=$bytes")
        $sw.Stop()
        return [math]::Round($d.Length * 8 / 1e6 / $sw.Elapsed.TotalSeconds, 1)
    } catch { return $null }
}

function Measure-Upload([int]$bytes) {
    try {
        $wc = New-Object Net.WebClient
        $buf = New-Object byte[] $bytes
        $sw = [Diagnostics.Stopwatch]::StartNew()
        [void]$wc.UploadData('https://speed.cloudflare.com/__up', 'POST', $buf)
        $sw.Stop()
        return [math]::Round($bytes * 8 / 1e6 / $sw.Elapsed.TotalSeconds, 1)
    } catch { return $null }
}

# ---------------------------------------------------------------------------
# 6. Cellular signal grading (4G/5G outdoor units and 4G routers)
# ---------------------------------------------------------------------------

function Get-CellGrades($cell) {
    if (-not $cell) { return $null }
    $g = [ordered]@{}
    $rsrp = Get-Num $cell['rsrp']; if ($null -eq $rsrp) { $rsrp = Get-Num $cell['Z5g_rsrp'] }
    $sinr = Get-Num $cell['sinr']; if ($null -eq $sinr) { $sinr = Get-Num $cell['Z5g_sinr'] }
    $rsrq = Get-Num $cell['rsrq']; if ($null -eq $rsrq) { $rsrq = Get-Num $cell['Z5g_rsrq'] }
    if ($null -ne $rsrp) {
        $grade = 'poor'; if ($rsrp -ge -80) { $grade = 'excellent' } elseif ($rsrp -ge -90) { $grade = 'good' } elseif ($rsrp -ge -100) { $grade = 'fair' }
        $g['rsrp'] = [ordered]@{ value = $rsrp; grade = $grade }
    }
    if ($null -ne $sinr) {
        $grade = 'poor'; if ($sinr -ge 20) { $grade = 'excellent' } elseif ($sinr -ge 13) { $grade = 'good' } elseif ($sinr -ge 5) { $grade = 'fair' }
        $g['sinr'] = [ordered]@{ value = $sinr; grade = $grade }
    }
    if ($null -ne $rsrq) {
        $grade = 'poor'; if ($rsrq -ge -10) { $grade = 'good' } elseif ($rsrq -ge -15) { $grade = 'fair' }
        $g['rsrq'] = [ordered]@{ value = $rsrq; grade = $grade }
    }
    if ($g.Count -eq 0) { return $null }
    return $g
}

# ---------------------------------------------------------------------------
# Run the tests
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host "Kebera $KeberaVersion - home internet check-up (read-only)" -ForegroundColor Green
Write-Host 'Nothing on your network will be changed. Press Ctrl+C to stop at any time.' -ForegroundColor Gray
Write-Host 'Kebera is NOT a hacking tool. Use it only on your own connection. See ACCEPTABLE_USE.md.' -ForegroundColor Gray

$report = [ordered]@{
    tool      = 'Kebera'
    version   = $KeberaVersion
    startedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    mode      = $(if ($Quick) { 'quick' } else { 'standard' })
}

Write-Step 'Checking how this computer is connected'
$net = Get-NetBasics
if (-not $net) {
    Write-Host 'No active network connection was found. Connect to your Wi-Fi or plug in a cable, then run Kebera again.' -ForegroundColor Red
    exit 1
}
$report.connection = $net
Write-Note ("{0} via {1}, router at {2}" -f $net.connection, $net.adapter, $net.gateway)

$wifi = $null
if ($net.connection -eq 'Wi-Fi') {
    $wifi = Get-WifiInfo
    if ($wifi -and $wifi.state -eq 'connected') { Write-Note ("Wi-Fi '{0}', {1}, channel {2}, signal {3}%" -f $wifi.ssid, $wifi.band, $wifi.channel, $wifi.signalPct) }
}
$report.wifi = $wifi

Write-Step 'Scanning nearby Wi-Fi networks'
$scan = Get-WifiScan
if (@($scan).Count -eq 0) { Write-Note 'No networks listed. On Windows 11, Wi-Fi scanning may need Location turned on (Settings > Privacy & security > Location).' }
else { Write-Note ("{0} access points visible" -f @($scan).Count) }
$crowd = Get-WifiCrowding $wifi $scan
$report.wifiNeighbourhood = [ordered]@{
    summary  = $crowd
    networks = @($scan | Sort-Object { [int]$_.channel } | ForEach-Object {
        $isMine = $wifi -and $wifi.ssid -and $_.ssid -and $_.ssid.StartsWith([string]$wifi.ssid)
        $name = Hide-Ssid $_.ssid
        if ($isMine) { $name = $_.ssid + ' (yours)' }
        [ordered]@{ name = $name; band = $_.band; channel = $_.channel; signalPct = $_.signalPct; stations = $_.stations; utilizationPct = $_.utilizationPct }
    })
}

Write-Step 'Tracing the route to the internet'
$trace = Get-Trace '8.8.8.8'
$report.traceroute = $trace
$upstream = $null
$hop2 = @($trace | Where-Object { $_.hop -eq 2 }) | Select-Object -First 1
if ($hop2 -and $hop2.ip -and (Test-PrivateIP $hop2.ip) -and $hop2.ip -ne $net.gateway) { $upstream = $hop2.ip }
Write-Note ("{0} hops recorded" -f @($trace).Count)

Write-Step 'Identifying your equipment (reading the pages they already show; no login)'
$devices = @()
$devices += Get-DeviceFingerprint $net.gateway 'Your router (the device your computer connects to)'
if ($upstream) { $devices += Get-DeviceFingerprint $upstream 'The next device after your router' }
foreach ($d in $devices) {
    $desc = @($d.vendor, $d.model, $d.role) | Where-Object { $_ }
    if ($desc.Count -eq 0) { if ($d.webPage) { $desc = @('unknown make') } else { $desc = @('no web page') } }
    Write-Note ("{0}: {1}" -f $d.ip, ($desc -join ', '))
}
$upDev = $null
if ($upstream) { $upDev = $devices | Where-Object { $_.ip -eq $upstream } | Select-Object -First 1 }
$upstreamIsCustomerKit = [bool]($upDev -and $upDev.webPage)
# A second device with its own management page right behind an indoor router is
# almost always the outdoor unit (4G/5G ODU) or the fibre modem (ONT).
if ($upstreamIsCustomerKit -and -not $upDev.role) {
    $gwDev = $devices | Where-Object { $_.ip -eq $net.gateway } | Select-Object -First 1
    if ($gwDev.role -eq 'Indoor router (CPE)' -or $upDev.vendor -in 'ZTE', 'Huawei') { $upDev.role = 'Outdoor 4G/5G unit (ODU) - likely' }
    else { $upDev.role = 'Outdoor unit or fibre modem - likely' }
    $upDev.evidence += 'It sits right after your router and has its own management page.'
}
$report.devices = $devices

$minutes = [math]::Ceiling($PingRounds * 0.5 / 60)
Write-Step "Measuring stability at the same moment on every link ($PingRounds rounds, about $minutes min)"
$targets = [ordered]@{ router = $net.gateway }
if ($upstream) { $targets['upstream'] = $upstream }
$targets['google'] = '8.8.8.8'
$targets['cloudflare'] = '1.1.1.1'
$samples = Measure-Targets $targets $PingRounds 500
$stats = [ordered]@{}
foreach ($k in $samples.Keys) { $stats[$k] = Get-PingStats $samples[$k] }

# Where did each failure happen? Compare the same moment on every link.
$ev = [ordered]@{ homeDrops = 0; upstreamDrops = 0; providerDrops = 0; providerSpikes = 0 }
for ($i = 0; $i -lt $PingRounds; $i++) {
    $r = $samples.router[$i]
    $u = $null; $uOk = $true
    if ($samples.Contains('upstream')) { $u = $samples.upstream[$i]; $uOk = ($null -ne $u) }
    $g = $samples.google[$i]; $c = $samples.cloudflare[$i]
    $netLost = ($null -eq $g) -and ($null -eq $c)
    if ($null -eq $r) { $ev.homeDrops++ }
    elseif (-not $uOk) { $ev.upstreamDrops++ }
    elseif ($netLost) { $ev.providerDrops++ }
    elseif ($null -ne $g -and $g -gt 300 -and $r -lt 50 -and ($null -eq $u -or $u -lt 80)) { $ev.providerSpikes++ }
}
$report.stability = [ordered]@{ rounds = $PingRounds; intervalSec = 0.5; targets = $targets; stats = $stats; events = $ev }
foreach ($k in $stats.Keys) { Write-Note ("{0,-10} loss {1,5}%  avg {2,6} ms  worst {3,6} ms  jitter {4,5} ms" -f $k, $stats[$k].lossPct, $stats[$k].avgMs, $stats[$k].maxMs, $stats[$k].jitterMs) }

Write-Step 'Comparing DNS speed (how fast website names are looked up)'
$names = 'google.com', 'youtube.com', 'facebook.com', 'whatsapp.com', 'xboxlive.com', 'microsoft.com', 'netflix.com', 'tiktok.com', 'wikipedia.org', 'cloudflare.com'
$dnsServers = @($net.dns) + @('1.1.1.1', '8.8.8.8') | Select-Object -Unique
$dnsRes = @()
foreach ($s in $dnsServers) { $dnsRes += Measure-Dns $s $names }
$report.dns = [ordered]@{ current = $net.dns; results = $dnsRes }
foreach ($d in $dnsRes) { Write-Note ("{0,-16} avg {1,5} ms  worst {2,5} ms  failed {3}" -f $d.server, $d.avgMs, $d.maxMs, $d.failed) }

$publicIp = $null
if (-not $NoInternetServices) {
    Write-Step 'Checking whether your provider shares one public address between customers (CGNAT)'
    try { $publicIp = [string](Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10) } catch { }
}
$wanIp = ($devices | Where-Object { $_.wanIp } | Select-Object -First 1).wanIp
$cgnat = 'unknown'
$cgnatWhy = ''
if ($wanIp -and (Test-PrivateIP $wanIp)) { $cgnat = 'yes'; $cgnatWhy = "Your equipment's internet address ($wanIp) is a private one." }
elseif ($wanIp -and $publicIp -and $wanIp -eq $publicIp) { $cgnat = 'no'; $cgnatWhy = 'Your equipment has its own public address.' }
else {
    $privBeyond = @($trace | Where-Object { $_.hop -ge 2 -and $_.hop -le 4 -and $_.ip -and (Test-PrivateIP $_.ip) -and $_.ip -ne $upstream })
    if ($privBeyond.Count -gt 0) { $cgnat = 'likely'; $cgnatWhy = 'Private addresses appear inside the provider network on the route.' }
}
$maskedPublic = $null
if ($publicIp -match '^(\d+\.\d+)\.\d+\.\d+$') { $maskedPublic = $Matches[1] + '.x.x' }
# Never store a full public address in the reports.
foreach ($d in $devices) {
    if ($d.wanIp -and -not (Test-PrivateIP $d.wanIp) -and $d.wanIp -match '^(\d+\.\d+)\.\d+\.\d+$') {
        $masked = $Matches[1] + '.x.x'
        foreach ($api in 'zte', 'huawei') { if ($d.raw.Contains($api)) { foreach ($k in @($d.raw[$api].Keys)) { if ($d.raw[$api][$k] -eq $d.wanIp) { $d.raw[$api][$k] = $masked } } } }
        $d.wanIp = $masked
    }
}
$report.address = [ordered]@{ publicIpMasked = $maskedPublic; cgnat = $cgnat; reason = $cgnatWhy }
Write-Note ("Shared address (CGNAT): {0}" -f $cgnat)

$speed = $null
if (-not $NoSpeedTest -and -not $NoInternetServices) {
    $downBytes = 25000000; $upBytes = 5000000
    if ($Quick) { $downBytes = 10000000; $upBytes = 2000000 }
    Write-Step ("Speed test (uses about {0} MB of data; skip with -NoSpeedTest)" -f [math]::Round(($downBytes + $upBytes) / 1e6))
    $down = Measure-Download $downBytes
    $up = Measure-Upload $upBytes
    $speed = [ordered]@{ downloadMbps = $down; uploadMbps = $up; server = 'speed.cloudflare.com' }
    Write-Note ("Download {0} Mbps, upload {1} Mbps" -f $down, $up)
}
$report.speed = $speed

# ---------------------------------------------------------------------------
# Diagnosis
# ---------------------------------------------------------------------------

$F = New-Object System.Collections.ArrayList
$rs = $stats.router
$us = $null; if ($stats.Contains('upstream')) { $us = $stats.upstream }
$gs = $stats.google; $cs = $stats.cloudflare
$internetLoss = [math]::Min($gs.lossPct, $cs.lossPct)
$pct = { param($n) [math]::Round(100.0 * $n / $PingRounds, 1) }
$upName = 'the next device after your router (outdoor unit, fibre modem or provider equipment)'
if ($upstreamIsCustomerKit) { $upName = 'your outdoor unit / modem' }

# Wi-Fi
if ($wifi -and $wifi.state -eq 'connected') {
    if ($wifi.signalPct -lt 40) {
        [void]$F.Add((New-Finding 'Home Wi-Fi' 'bad' 'Weak Wi-Fi signal on this computer' "Signal is only $($wifi.signalPct)%." 'Move closer to the router, remove obstacles, or use a cable.'))
    } elseif ($wifi.signalPct -lt 60) {
        [void]$F.Add((New-Finding 'Home Wi-Fi' 'warn' 'Wi-Fi signal is only moderate' "Signal is $($wifi.signalPct)%." 'Move a little closer to the router if you can.'))
    }
    if ($crowd) {
        if ($crowd.band -eq '2.4 GHz' -and $crowd.strongOverlapping -ge 2) {
            $fix = 'Use 5 GHz for nearby devices.'
            if ($crowd.suggested24Channel -and $crowd.suggested24Channel -ne $crowd.channel) { $fix += " For 2.4 GHz, set the router to channel $($crowd.suggested24Channel)." }
            [void]$F.Add((New-Finding 'Home Wi-Fi' 'warn' 'Neighbours share your Wi-Fi channel' "$($crowd.strongOverlapping) strong neighbouring networks overlap your channel $($crowd.channel). Devices on the same channel take turns, so their traffic slows yours." $fix))
        }
        if ($crowd.band -eq '2.4 GHz' -and $crowd.own5GHzVisible) {
            [void]$F.Add((New-Finding 'Home Wi-Fi' 'info' 'This computer is on 2.4 GHz although your router also offers 5 GHz' "Your 5 GHz network ($($crowd.own5GHzName)) is visible at $($crowd.own5GHzSignalPct)%." 'Connect to the 5 GHz network, or set the Wi-Fi adapter to "Prefer 5GHz band" in Device Manager.'))
        }
        if ($null -ne $crowd.ownUtilizationPct -and $crowd.ownUtilizationPct -ge 60) {
            [void]$F.Add((New-Finding 'Home Wi-Fi' 'warn' 'Your Wi-Fi channel is very busy' "The router reports $($crowd.ownUtilizationPct)% channel use." 'Check for heavy downloads or streaming on other devices, or change channel.'))
        }
    }
}

# Home link (computer <-> router)
$routerJustSlowToReply = $false
if ($us -and $rs.lossPct -ge 1 -and $us.lossPct -lt $rs.lossPct) { $routerJustSlowToReply = $true }
if ($routerJustSlowToReply) {
    [void]$F.Add((New-Finding 'Your router' 'info' 'Your router sometimes ignores pings sent to it' "It missed $($rs.lossPct)% of pings, but traffic passing through it to $upName lost only $($us.lossPct)%." 'Nothing to fix. Many routers answer pings last when busy.'))
} elseif ($rs.lossPct -ge 3 -or (& $pct $ev.homeDrops) -ge 3) {
    $area = 'Home Wi-Fi'; $fix = 'Move closer to the router, switch to 5 GHz, change Wi-Fi channel, or restart the router.'
    if ($net.connection -eq 'Wired') { $area = 'Your router'; $fix = 'Try another cable and router port. If it continues, restart or replace the router.' }
    [void]$F.Add((New-Finding $area 'bad' 'The connection between this computer and your router is unreliable' "$($rs.lossPct)% of pings to the router were lost." $fix))
} elseif ($rs.lossPct -ge 1) {
    [void]$F.Add((New-Finding 'Home Wi-Fi' 'warn' 'A few pings to your router were lost' "$($rs.lossPct)% loss to the router." 'Usually minor. Re-test closer to the router to compare.'))
}
if ($net.connection -eq 'Wi-Fi' -and $rs.p95Ms -gt 100 -and -not $routerJustSlowToReply) {
    [void]$F.Add((New-Finding 'Home Wi-Fi' 'warn' 'Wi-Fi delay spikes' "1 in 20 pings to your router took over $($rs.p95Ms) ms (should be under 20 ms)." 'Try 5 GHz, move closer, or check Wi-Fi power-saving settings.'))
}

# Router <-> upstream device
if ($us) {
    $upEvPct = & $pct $ev.upstreamDrops
    if ($upEvPct -ge 2 -or ($us.lossPct - $rs.lossPct) -ge 2) {
        $area = 'Provider network'
        $fix = 'Report it to your provider.'
        if ($upstreamIsCustomerKit) { $area = 'Outdoor unit / modem'; $fix = 'Check the cable and power adapter between your router and that unit, look for water damage on outdoor cables, and restart the unit. If it persists, ask your provider to check the unit.' }
        [void]$F.Add((New-Finding $area 'bad' "Drops between your router and $upName" "$upEvPct% of the time your router answered but $upName did not." $fix))
    }
}

# Provider / internet
$provPct = & $pct $ev.providerDrops
if ($provPct -ge 2 -or ($internetLoss - [math]::Max($rs.lossPct, $(if ($us) { $us.lossPct } else { 0 }))) -ge 2) {
    [void]$F.Add((New-Finding 'Provider network' 'bad' 'Connection drops happen beyond your equipment' "At $provPct% of moments, your own equipment answered but both Google and Cloudflare did not. Overall internet loss: $internetLoss%." 'Report it to your provider with this report. Ask them to check the tower or line serving you.'))
} elseif ($internetLoss -ge 1) {
    [void]$F.Add((New-Finding 'Provider network' 'warn' 'Some packet loss on the internet side' "Internet loss was $internetLoss% while your equipment was stable." 'Run the long logger to see whether it gets worse at busy times.'))
}
if ($gs.avgMs -gt 150) {
    [void]$F.Add((New-Finding 'Provider network' 'warn' 'High delay to the internet' "Average delay to Google was $($gs.avgMs) ms (a healthy home connection in Uganda is usually under 80 ms)." 'Usually network congestion. Note the times of day it happens.'))
}
if ($gs.jitterMs -gt 40) {
    [void]$F.Add((New-Finding 'Provider network' 'bad' 'Very unstable delay (jitter)' "Delay jumped around by $($gs.jitterMs) ms on average. Calls stutter and games lag above about 30 ms." 'Typical of a congested mobile network. Report it with this report.'))
} elseif ($gs.jitterMs -gt 20) {
    [void]$F.Add((New-Finding 'Provider network' 'warn' 'Unstable delay (jitter)' "Delay jumped around by $($gs.jitterMs) ms on average." 'Watch whether it is worse in the evenings.'))
}
if ((& $pct $ev.providerSpikes) -ge 5) {
    [void]$F.Add((New-Finding 'Provider network' 'warn' 'Frequent lag spikes beyond your equipment' "$(& $pct $ev.providerSpikes)% of moments had internet delay over 300 ms while your home network was fast." 'Report it with this report.'))
}

# Cellular readings from the equipment, if it shared them without a login
foreach ($d in $devices) {
    $grades = Get-CellGrades $d.cellular
    if ($grades) {
        $d.cellGrades = $grades
        $txt = @()
        foreach ($k in $grades.Keys) { $txt += ("{0} {1} ({2})" -f $k.ToUpper(), $grades[$k].value, $grades[$k].grade) }
        $sev = 'ok'
        if ($grades.Contains('sinr') -and $grades.sinr.grade -eq 'poor') { $sev = 'bad' } elseif (($grades.Contains('sinr') -and $grades.sinr.grade -eq 'fair') -or ($grades.Contains('rsrp') -and $grades.rsrp.grade -eq 'poor')) { $sev = 'warn' }
        $title = 'Mobile signal at your outdoor unit / router'
        $fix = 'Signal looks fine.'
        if ($grades.Contains('rsrp') -and $grades.Contains('sinr') -and ($grades.rsrp.grade -in 'excellent', 'good') -and ($grades.sinr.grade -in 'fair', 'poor')) {
            $title = 'Strong but noisy mobile signal'
            $fix = 'Strong signal with poor quality usually means a busy cell or interference. Ask your provider to check the cell; re-aiming an outdoor unit can also help.'
        } elseif ($grades.Contains('rsrp') -and $grades.rsrp.grade -eq 'poor') {
            $fix = 'Weak signal. Move the router near a window or higher up, or ask the provider about an outdoor unit or re-aiming.'
        }
        [void]$F.Add((New-Finding 'Outdoor unit / modem' $sev $title ($txt -join ', ') $fix))
    }
}

# Speed
if ($speed -and $null -ne $speed.downloadMbps) {
    if ($speed.downloadMbps -lt 5) { [void]$F.Add((New-Finding 'Provider network' 'bad' 'Very slow download speed' "$($speed.downloadMbps) Mbps download." 'If your home network tested fine, ask the provider whether your line is limited (for example after a fair-usage threshold).')) }
    elseif ($speed.downloadMbps -lt 10) { [void]$F.Add((New-Finding 'Provider network' 'warn' 'Slow download speed' "$($speed.downloadMbps) Mbps download." 'Compare with what your plan promises.')) }
    else { [void]$F.Add((New-Finding 'Provider network' 'ok' 'Download speed is reasonable right now' "$($speed.downloadMbps) Mbps down, $($speed.uploadMbps) Mbps up." '')) }
}

# DNS
$cur = @($dnsRes | Where-Object { $net.dns -contains $_.server -and $null -ne $_.avgMs })
$pub = @($dnsRes | Where-Object { @('1.1.1.1', '8.8.8.8') -contains $_.server -and $null -ne $_.avgMs } | Sort-Object { $_.avgMs })
if ($cur.Count -gt 0 -and $pub.Count -gt 0) {
    $curAvg = ($cur | ForEach-Object { $_.avgMs } | Measure-Object -Average).Average
    $bestPub = $pub[0]
    if (($net.dns | Where-Object { @('1.1.1.1', '8.8.8.8', '8.8.4.4', '1.0.0.1') -contains $_ }).Count -eq 0 -and $curAvg - $bestPub.avgMs -ge 50) {
        [void]$F.Add((New-Finding 'DNS' 'warn' 'Your current DNS is slow' ("Lookups took about {0} ms with your current DNS, versus {1} ms with {2}." -f [math]::Round($curAvg), $bestPub.avgMs, $bestPub.server) 'Set DNS to 1.1.1.1 and 8.8.8.8 on the device (or in the router). It speeds up opening sites and apps, not downloads.'))
    }
}
if (@($dnsRes | Where-Object { $_.failed -gt 2 }).Count -gt 0) {
    [void]$F.Add((New-Finding 'DNS' 'warn' 'Some DNS lookups failed' 'One or more DNS servers did not answer several lookups.' 'Try public DNS such as 1.1.1.1 and 8.8.8.8.'))
}

# Address sharing
if ($cgnat -in 'yes', 'likely') {
    [void]$F.Add((New-Finding 'Provider network' 'info' 'Your provider shares one public address between customers (CGNAT)' $cgnatWhy 'Normal on mobile/5G home internet. It can make game consoles show Strict NAT and prevents port forwarding. Ask the provider for a public IP if you need one.'))
}

# Verdict
$order = @{ 'bad' = 0; 'warn' = 1; 'info' = 2; 'ok' = 3 }
$sortedF = @($F | Sort-Object { $order[$_.severity] })
$badAreas = @($F | Where-Object { $_.severity -eq 'bad' } | ForEach-Object { $_.area } | Select-Object -Unique)
$localBad = @($badAreas | Where-Object { $_ -in 'Home Wi-Fi', 'Your router', 'This computer' })
$verdictArea = 'none'
if ($badAreas.Count -eq 0) {
    $verdict = 'No major problem showed up during this test.'
    $verdictDetail = 'If your internet still misbehaves at certain times, run the long logger (kebera-log) for a few hours to catch it in the act.'
} elseif ($localBad.Count -gt 0 -and ($badAreas | Where-Object { $_ -notin $localBad }).Count -gt 0) {
    $verdictArea = 'mixed'
    $verdict = 'Problems were found both inside your home and beyond it.'
    $verdictDetail = 'Fix the home Wi-Fi/router items first (they are free and quick), then re-run Kebera before contacting your provider.'
} elseif ($localBad.Count -gt 0) {
    $verdictArea = 'home'
    $verdict = 'The main problem is inside your home: your Wi-Fi or router.'
    $verdictDetail = 'Your provider connection looked healthy whenever your home network was working.'
} elseif ($badAreas -contains 'Outdoor unit / modem' -and $badAreas -notcontains 'Provider network') {
    $verdictArea = 'equipment'
    $verdict = 'The main problem is at your outdoor unit / modem or its cable.'
    $verdictDetail = 'Your home network is fine, but the link to that unit is unreliable or its signal is poor.'
} else {
    $verdictArea = 'provider'
    $verdict = 'The main problem is on your internet provider''s side.'
    $verdictDetail = 'Your devices, Wi-Fi and router stayed healthy while the connection beyond them dropped or lagged.'
}
$report.findings = $sortedF
$report.verdict = [ordered]@{ area = $verdictArea; headline = $verdict; detail = $verdictDetail }
$report.finishedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')

# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

$provider = ($devices | Where-Object { $_.provider } | Select-Object -First 1).provider
if (-not $provider) { $provider = '[your provider]' }
$label = @{ router = 'Your router'; upstream = 'Next device (outdoor unit / modem / provider)'; google = 'Internet: Google (8.8.8.8)'; cloudflare = 'Internet: Cloudflare (1.1.1.1)' }
$sevWord = @{ bad = 'PROBLEM'; warn = 'WATCH'; info = 'NOTE'; ok = 'OK' }

# --- Markdown -------------------------------------------------------------
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Kebera internet check-up')
[void]$md.AppendLine('')
[void]$md.AppendLine("Date: $($report.startedAt)  |  Mode: $($report.mode)  |  Kebera $KeberaVersion")
[void]$md.AppendLine('')
[void]$md.AppendLine('## Verdict')
[void]$md.AppendLine('')
[void]$md.AppendLine("**$verdict**")
[void]$md.AppendLine('')
[void]$md.AppendLine($verdictDetail)
[void]$md.AppendLine('')
[void]$md.AppendLine('## What we found')
[void]$md.AppendLine('')
foreach ($f in $sortedF) {
    [void]$md.AppendLine("- **[$($sevWord[$f.severity])] $($f.title)** ($($f.area)). $($f.detail)")
    if ($f.fix) { [void]$md.AppendLine("  - What to do: $($f.fix)") }
}
if ($sortedF.Count -eq 0) { [void]$md.AppendLine('- Nothing unusual.') }
[void]$md.AppendLine('')
[void]$md.AppendLine('## Your setup')
[void]$md.AppendLine('')
[void]$md.AppendLine("- This computer: $($net.connection) ($($net.description))")
if ($wifi -and $wifi.state -eq 'connected') { [void]$md.AppendLine("- Wi-Fi: $($wifi.ssid), $($wifi.band), channel $($wifi.channel), signal $($wifi.signalPct)%, link $($wifi.rxMbps) Mbps") }
foreach ($d in $devices) {
    $parts = @($d.vendor, $d.model, $d.role, $d.provider) | Where-Object { $_ }
    $what = 'not identified'; if ($parts.Count -gt 0) { $what = $parts -join ', ' }
    [void]$md.AppendLine("- $($d.label) at $($d.ip): $what")
}
[void]$md.AppendLine("- Shared public address (CGNAT): $cgnat")
[void]$md.AppendLine('')
[void]$md.AppendLine("## Stability ($PingRounds checks, every 0.5 s, all links at the same moment)")
[void]$md.AppendLine('')
[void]$md.AppendLine('| Link | Lost | Average | Worst | Jitter |')
[void]$md.AppendLine('|---|---|---|---|---|')
foreach ($k in $stats.Keys) { $s = $stats[$k]; [void]$md.AppendLine("| $($label[$k]) | $($s.lossPct)% | $($s.avgMs) ms | $($s.maxMs) ms | $($s.jitterMs) ms |") }
[void]$md.AppendLine('')
[void]$md.AppendLine("Moments when the problem was inside the home: $($ev.homeDrops). Between router and next device: $($ev.upstreamDrops). Beyond your equipment (provider): $($ev.providerDrops). Provider lag spikes over 300 ms: $($ev.providerSpikes).")
[void]$md.AppendLine('')
if ($speed) { [void]$md.AppendLine("## Speed`n`nDownload $($speed.downloadMbps) Mbps, upload $($speed.uploadMbps) Mbps (server: speed.cloudflare.com).`n") }
[void]$md.AppendLine('## DNS (name lookup) speed')
[void]$md.AppendLine('')
[void]$md.AppendLine('| Server | Average | Worst | Failed |')
[void]$md.AppendLine('|---|---|---|---|')
foreach ($d in $dnsRes) { $tag = ''; if ($net.dns -contains $d.server) { $tag = ' (current)' }; [void]$md.AppendLine("| $($d.server)$tag | $($d.avgMs) ms | $($d.maxMs) ms | $($d.failed) |") }
[void]$md.AppendLine('')
if (@($scan).Count -gt 0) {
    [void]$md.AppendLine('## Wi-Fi neighbourhood (neighbour names hidden)')
    [void]$md.AppendLine('')
    [void]$md.AppendLine('| Network | Band | Channel | Signal |')
    [void]$md.AppendLine('|---|---|---|---|')
    foreach ($n in $report.wifiNeighbourhood.networks) { [void]$md.AppendLine("| $($n.name) | $($n.band) | $($n.channel) | $($n.signalPct)% |") }
    [void]$md.AppendLine('')
}
[void]$md.AppendLine('## Route to the internet')
[void]$md.AppendLine('')
foreach ($h in $trace) {
    $t = ($h.timesMs | ForEach-Object { if ($null -eq $_) { '*' } else { "$_ ms" } }) -join ', '
    $ipTxt = $h.ip; if (-not $ipTxt) { $ipTxt = '(no reply - normal for many provider routers)' }
    [void]$md.AppendLine("$($h.hop). $ipTxt  [$t]")
}
[void]$md.AppendLine('')
[void]$md.AppendLine('---')
[void]$md.AppendLine('Generated by Kebera, a read-only, open-source check-up. Results describe the moment of the test. A single test can miss problems that come and go; use the long logger for those. Neighbour network names, MAC addresses and your full public IP are not included.')
$md.ToString() | Out-File -Encoding utf8 (Join-Path $OutDir 'report.md')

# --- Message for the provider --------------------------------------------
$msg = New-Object System.Text.StringBuilder
[void]$msg.AppendLine("Hello $provider team,")
[void]$msg.AppendLine('')
[void]$msg.AppendLine('My home internet (account/line: [your number]) has been [slow / dropping / lagging]. I ran a check-up on ' + $report.startedAt + ' and these are the results:')
[void]$msg.AppendLine('')
[void]$msg.AppendLine(("- My own router: {0}% loss, average {1} ms" -f $rs.lossPct, $rs.avgMs))
if ($us) { [void]$msg.AppendLine(("- The next device ({0}): {1}% loss, average {2} ms" -f $upName, $us.lossPct, $us.avgMs)) }
[void]$msg.AppendLine(("- The internet (Google/Cloudflare): {0}% loss, average {1} ms, worst {2} ms, jitter {3} ms" -f $internetLoss, $gs.avgMs, $gs.maxMs, $gs.jitterMs))
if ($ev.providerDrops -gt 0) { [void]$msg.AppendLine(("- {0} moments where my equipment answered but the internet did not" -f $ev.providerDrops)) }
if ($speed) { [void]$msg.AppendLine(("- Speed: {0} Mbps down, {1} Mbps up" -f $speed.downloadMbps, $speed.uploadMbps)) }
foreach ($d in $devices) { if ($d.cellGrades) { $t = @(); foreach ($k in $d.cellGrades.Keys) { $t += ("{0} {1}" -f $k.ToUpper(), $d.cellGrades[$k].value) }; [void]$msg.AppendLine("- Signal at my unit: " + ($t -join ', ')) } }
[void]$msg.AppendLine('')
[void]$msg.AppendLine('Conclusion: ' + $verdict)
[void]$msg.AppendLine('')
if ($verdictArea -in 'provider', 'mixed', 'none') {
    [void]$msg.AppendLine('Please check the network serving my area (tower or line), tell me whether my line is being limited for any reason, and send me a reference number for this complaint.')
} else {
    [void]$msg.AppendLine('Please advise, and send me a reference number for this request.')
}
[void]$msg.AppendLine('')
[void]$msg.AppendLine('Thank you,')
[void]$msg.AppendLine('[Your name]')
[void]$msg.AppendLine('[Area / location]')
$msg.ToString() | Out-File -Encoding utf8 (Join-Path $OutDir 'message-to-provider.txt')

# --- JSON (for AI agents and tools) ---------------------------------------
$report | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 (Join-Path $OutDir 'report.json')

# --- HTML -------------------------------------------------------------------
function HtmlEnc([string]$s) { return [System.Net.WebUtility]::HtmlEncode($s) }
$css = @'
:root{--bg:#f6f7f9;--card:#fff;--ink:#1d2433;--muted:#5b6475;--line:#e3e6ec;--bad:#c62828;--warn:#b26a00;--info:#1565c0;--ok:#2e7d32;--accent:#d4a017}
@media (prefers-color-scheme:dark){:root{--bg:#12151b;--card:#1b2029;--ink:#e8ebf1;--muted:#a3abba;--line:#2c3340;--bad:#ef5350;--warn:#ffb74d;--info:#64b5f6;--ok:#81c784}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:900px;margin:0 auto;padding:24px 16px 48px}h1{margin:0 0 4px;font-size:26px}h2{font-size:18px;margin:28px 0 10px}
.meta{color:var(--muted);font-size:13px}.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:16px 18px;margin:12px 0}
.verdict{border-left:6px solid var(--accent)}.verdict b{font-size:19px;display:block;margin-bottom:4px}
.f{display:flex;gap:12px;align-items:flex-start}.tag{flex:none;font-size:11px;font-weight:700;letter-spacing:.04em;padding:3px 8px;border-radius:999px;color:#fff;margin-top:2px}
.bad{background:var(--bad)}.warn{background:var(--warn)}.info{background:var(--info)}.ok{background:var(--ok)}
.area{color:var(--muted);font-size:12px}.fix{margin-top:4px}.fix:before{content:"What to do: ";font-weight:600}
table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:7px 8px;border-bottom:1px solid var(--line)}th{color:var(--muted);font-weight:600}
.scroll{overflow-x:auto}.chain{display:flex;flex-wrap:wrap;gap:6px;align-items:center;font-size:14px}.chain span{background:var(--bg);border:1px solid var(--line);border-radius:8px;padding:6px 10px}
footer{color:var(--muted);font-size:12px;margin-top:32px}
'@
$h = New-Object System.Text.StringBuilder
[void]$h.AppendLine('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Kebera report</title><style>' + $css + '</style></head><body><div class="wrap">')
[void]$h.AppendLine('<h1>Kebera internet check-up</h1><div class="meta">' + (HtmlEnc "$($report.startedAt) | $($report.mode) test | Kebera $KeberaVersion") + '</div>')
[void]$h.AppendLine('<div class="card verdict"><b>' + (HtmlEnc $verdict) + '</b>' + (HtmlEnc $verdictDetail) + '</div>')
$chain = @('This computer (' + $net.connection + ')')
foreach ($d in $devices) { $p = @($d.vendor, $d.model) | Where-Object { $_ }; $n = 'Router'; if ($d.ip -ne $net.gateway) { $n = 'Next device' }; if ($p.Count -gt 0) { $n += ': ' + ($p -join ' ') }; $chain += $n }
$chain += "$provider network"; $chain += 'Internet'
[void]$h.AppendLine('<div class="chain">' + (($chain | ForEach-Object { '<span>' + (HtmlEnc $_) + '</span>' }) -join ' &rarr; ') + '</div>')
[void]$h.AppendLine('<h2>What we found</h2>')
foreach ($f in $sortedF) {
    [void]$h.AppendLine('<div class="card f"><span class="tag ' + $f.severity + '">' + $sevWord[$f.severity] + '</span><div><div><b>' + (HtmlEnc $f.title) + '</b> <span class="area">' + (HtmlEnc $f.area) + '</span></div><div>' + (HtmlEnc $f.detail) + '</div>' + $(if ($f.fix) { '<div class="fix">' + (HtmlEnc $f.fix) + '</div>' } else { '' }) + '</div></div>')
}
[void]$h.AppendLine("<h2>Stability ($PingRounds checks, all links at the same moment)</h2><div class=""card scroll""><table><tr><th>Link</th><th>Lost</th><th>Average</th><th>Worst</th><th>Jitter</th></tr>")
foreach ($k in $stats.Keys) { $s = $stats[$k]; [void]$h.AppendLine("<tr><td>$(HtmlEnc $label[$k])</td><td>$($s.lossPct)%</td><td>$($s.avgMs) ms</td><td>$($s.maxMs) ms</td><td>$($s.jitterMs) ms</td></tr>") }
[void]$h.AppendLine('</table></div>')
if ($speed) { [void]$h.AppendLine("<h2>Speed</h2><div class=""card"">Download <b>$($speed.downloadMbps) Mbps</b>, upload <b>$($speed.uploadMbps) Mbps</b></div>") }
[void]$h.AppendLine('<h2>DNS speed</h2><div class="card scroll"><table><tr><th>Server</th><th>Average</th><th>Worst</th><th>Failed</th></tr>')
foreach ($d in $dnsRes) { $tag = ''; if ($net.dns -contains $d.server) { $tag = ' (current)' }; [void]$h.AppendLine("<tr><td>$($d.server)$tag</td><td>$($d.avgMs) ms</td><td>$($d.maxMs) ms</td><td>$($d.failed)</td></tr>") }
[void]$h.AppendLine('</table></div>')
if (@($scan).Count -gt 0) {
    [void]$h.AppendLine('<h2>Wi-Fi neighbourhood</h2><div class="card scroll"><table><tr><th>Network</th><th>Band</th><th>Channel</th><th>Signal</th></tr>')
    foreach ($n in $report.wifiNeighbourhood.networks) { [void]$h.AppendLine("<tr><td>$(HtmlEnc $n.name)</td><td>$($n.band)</td><td>$($n.channel)</td><td>$($n.signalPct)%</td></tr>") }
    [void]$h.AppendLine('</table></div>')
}
[void]$h.AppendLine('<footer>Generated by Kebera, a read-only open-source check-up. Neighbour network names, MAC addresses and your full public IP are not included. A short test can miss problems that come and go; run the long logger for those.</footer></div></body></html>')
$h.ToString() | Out-File -Encoding utf8 (Join-Path $OutDir 'report.html')

Write-Host ''
Write-Host '==================================================================' -ForegroundColor Green
Write-Host " VERDICT: $verdict" -ForegroundColor Yellow
Write-Host " $verdictDetail"
Write-Host '==================================================================' -ForegroundColor Green
Write-Host "Reports saved in: $OutDir"
Write-Host '  report.html               - open in your browser'
Write-Host '  report.md                 - same report as text'
Write-Host '  message-to-provider.txt   - ready-to-send complaint draft'
Write-Host '  report.json               - full data (for AI agents)'
if (-not $NoOpen) { try { Start-Process (Join-Path $OutDir 'report.html') } catch { } }
