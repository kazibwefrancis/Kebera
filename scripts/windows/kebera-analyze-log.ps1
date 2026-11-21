<#
.SYNOPSIS
    Analyses a Kebera log (from kebera-log.ps1) and explains where problems happened.

.DESCRIPTION
    For every reading it compares all links at the same moment:
      - router lost                         -> problem inside the home (Wi-Fi / router)
      - router fine, next device lost       -> problem between router and outdoor unit / modem
      - both fine, Google AND Cloudflare lost -> problem in the provider network
    It also finds outages (several failed readings in a row), lag spikes and the
    busiest hours, then writes <log>-report.md next to the log.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera-analyze-log.ps1 -LogFile .\reports\kebera-log_2026-11-21_1044.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LogFile,
    [int]$SpikeMs = 300
)

if (-not (Test-Path $LogFile)) { Write-Host "Log not found: $LogFile" -ForegroundColor Red; exit 1 }
$rows = @(Import-Csv $LogFile)
if ($rows.Count -lt 2) { Write-Host 'Not enough readings yet.' -ForegroundColor Yellow; exit 1 }

# Accept older column names too (odu_ms was used before upstream_ms).
$upCol = $null
foreach ($c in 'upstream_ms', 'odu_ms') { if ($rows[0].PSObject.Properties.Name -contains $c) { $upCol = $c; break } }
$hasUp = $false
if ($upCol) { $hasUp = @($rows | Where-Object { $_.$upCol -ne '' -and $null -ne $_.$upCol }).Count -gt 0 }

function Get-Val($v) { if ($null -eq $v -or $v -eq '' -or $v -eq 'LOST') { return $null }; return [int]$v }

$cols = [ordered]@{ router = 'router_ms' }
if ($hasUp) { $cols['upstream'] = $upCol }
$cols['google'] = 'google_ms'; $cols['cloudflare'] = 'cloudflare_ms'

$stats = [ordered]@{}
foreach ($k in $cols.Keys) {
    $vals = @($rows | ForEach-Object { Get-Val $_.($cols[$k]) })
    $ok = @($vals | Where-Object { $null -ne $_ })
    $lost = $vals.Count - $ok.Count
    $sorted = @($ok | Sort-Object)
    $stats[$k] = [ordered]@{
        lost = $lost
        lossPct = [math]::Round(100.0 * $lost / [math]::Max(1, $vals.Count), 2)
        avg = $(if ($ok.Count) { [math]::Round(($ok | Measure-Object -Average).Average) } else { $null })
        p95 = $(if ($ok.Count) { $sorted[[math]::Min($sorted.Count - 1, [int][math]::Floor($sorted.Count * 0.95))] } else { $null })
        max = $(if ($ok.Count) { $sorted[-1] } else { $null })
    }
}

# Classify every reading
$events = New-Object System.Collections.ArrayList
$counts = [ordered]@{ home = 0; upstream = 0; provider = 0; providerSpike = 0 }
$hourly = @{}
foreach ($r in $rows) {
    $rt = Get-Val $r.router_ms
    $ut = $null; if ($hasUp) { $ut = Get-Val $r.$upCol }
    $gt = Get-Val $r.google_ms; $ct = Get-Val $r.cloudflare_ms
    $kind = $null
    if ($null -eq $rt) { $kind = 'home' }
    elseif ($hasUp -and $null -eq $ut) { $kind = 'upstream' }
    elseif ($null -eq $gt -and $null -eq $ct) { $kind = 'provider' }
    else {
        $best = @($gt, $ct | Where-Object { $null -ne $_ } | Sort-Object)[0]
        if ($best -gt $SpikeMs -and $rt -lt 80 -and ($null -eq $ut -or $ut -lt 120)) { $kind = 'providerSpike' }
    }
    if ($kind) { $counts[$kind]++; [void]$events.Add([pscustomobject]@{ time = $r.time; kind = $kind }) }

    $hr = ([datetime]$r.time).ToString('yyyy-MM-dd HH:00')
    if (-not $hourly.ContainsKey($hr)) { $hourly[$hr] = [ordered]@{ n = 0; sumG = 0; nG = 0; lostNet = 0; spikes = 0; home = 0 } }
    $hh = $hourly[$hr]; $hh.n++
    if ($null -ne $gt) { $hh.sumG += $gt; $hh.nG++ }
    if ($kind -eq 'provider') { $hh.lostNet++ }
    if ($kind -eq 'providerSpike') { $hh.spikes++ }
    if ($kind -eq 'home') { $hh.home++ }
}

# Outages: 3+ consecutive readings with no internet (both public targets lost)
$outages = New-Object System.Collections.ArrayList
$run = @()
foreach ($r in $rows) {
    $lost = ($null -eq (Get-Val $r.google_ms)) -and ($null -eq (Get-Val $r.cloudflare_ms))
    if ($lost) { $run += $r } else {
        if ($run.Count -ge 3) {
            $where = 'provider'
            if (@($run | Where-Object { $null -eq (Get-Val $_.router_ms) }).Count -ge [math]::Ceiling($run.Count / 2)) { $where = 'home' }
            elseif ($hasUp -and @($run | Where-Object { $null -eq (Get-Val $_.$upCol) }).Count -ge [math]::Ceiling($run.Count / 2)) { $where = 'upstream' }
            [void]$outages.Add([pscustomobject]@{ start = $run[0].time; end = $run[-1].time; readings = $run.Count; where = $where })
        }
        $run = @()
    }
}

$first = [datetime]$rows[0].time; $last = [datetime]$rows[-1].time
$dur = $last - $first
$n = $rows.Count
$pct = { param($x) [math]::Round(100.0 * $x / $n, 2) }

# Verdict
$homePct = & $pct $counts.home; $upPct = & $pct $counts.upstream; $provPct = & $pct $counts.provider; $spikePct = & $pct $counts.providerSpike
if ($homePct -ge 1 -and $homePct -ge $provPct) { $verdict = 'Most failures happened inside the home (Wi-Fi or router).' }
elseif ($upPct -ge 1 -and $upPct -ge $provPct) { $verdict = 'Most failures happened between your router and the outdoor unit / modem.' }
elseif ($provPct -ge 0.5 -or $spikePct -ge 2 -or $outages.Count -gt 0) { $verdict = 'Most problems happened beyond your equipment, in the provider network.' }
else { $verdict = 'The connection was mostly stable during this log.' }

$labels = @{ router = 'Your router'; upstream = 'Next device (outdoor unit / modem)'; google = 'Google 8.8.8.8'; cloudflare = 'Cloudflare 1.1.1.1' }
$whereTxt = @{ home = 'inside the home'; upstream = 'router to outdoor unit / modem'; provider = 'provider network' }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# Kebera long-log report')
[void]$sb.AppendLine('')
[void]$sb.AppendLine(("Log: {0} to {1} ({2:N1} hours, {3} readings)" -f $first.ToString('yyyy-MM-dd HH:mm'), $last.ToString('HH:mm'), $dur.TotalHours, $n))
[void]$sb.AppendLine('')
[void]$sb.AppendLine("## Verdict`n`n**$verdict**`n")
[void]$sb.AppendLine('## Where problems happened')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| Where | Readings | Share |')
[void]$sb.AppendLine('|---|---|---|')
[void]$sb.AppendLine("| Inside the home (router not answering) | $($counts.home) | $homePct% |")
if ($hasUp) { [void]$sb.AppendLine("| Router to outdoor unit / modem | $($counts.upstream) | $upPct% |") }
[void]$sb.AppendLine("| Provider network (your equipment fine, internet lost) | $($counts.provider) | $provPct% |")
[void]$sb.AppendLine("| Provider lag spikes over $SpikeMs ms (home fast) | $($counts.providerSpike) | $spikePct% |")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Each link')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| Link | Lost | Average | 95% under | Worst |')
[void]$sb.AppendLine('|---|---|---|---|---|')
foreach ($k in $stats.Keys) { $s = $stats[$k]; [void]$sb.AppendLine("| $($labels[$k]) | $($s.lost) ($($s.lossPct)%) | $($s.avg) ms | $($s.p95) ms | $($s.max) ms |") }
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Outages (3 or more readings in a row with no internet)')
[void]$sb.AppendLine('')
if ($outages.Count -eq 0) { [void]$sb.AppendLine('None.') }
foreach ($o in $outages) { [void]$sb.AppendLine("- $($o.start) to $($o.end) ($($o.readings) readings) - $($whereTxt[$o.where])") }
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## Hour by hour')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('| Hour | Avg delay to Google | Internet lost | Lag spikes | Home drops |')
[void]$sb.AppendLine('|---|---|---|---|---|')
foreach ($k in ($hourly.Keys | Sort-Object)) {
    $hh = $hourly[$k]
    $avg = '-'; if ($hh.nG) { $avg = [math]::Round($hh.sumG / $hh.nG) }
    [void]$sb.AppendLine("| $k | $avg ms | $($hh.lostNet) | $($hh.spikes) | $($hh.home) |")
}
[void]$sb.AppendLine('')
$worst = @($events | Where-Object { $_.kind -ne 'providerSpike' } | Select-Object -First 15)
if ($worst.Count -gt 0) {
    [void]$sb.AppendLine('## First failed readings')
    [void]$sb.AppendLine('')
    foreach ($e in $worst) { [void]$sb.AppendLine("- $($e.time): $($whereTxt[$e.kind])") }
    [void]$sb.AppendLine('')
}
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('Generated by Kebera. "Lost" means no reply within 2 seconds. Routers sometimes ignore pings to themselves when busy; if the router shows loss but the next device does not, that is usually harmless.')

$outPath = [IO.Path]::ChangeExtension($LogFile, $null).TrimEnd('.') + '-report.md'
$sb.ToString() | Out-File -Encoding utf8 $outPath

Write-Host ''
Write-Host "VERDICT: $verdict" -ForegroundColor Yellow
foreach ($k in $stats.Keys) { $s = $stats[$k]; Write-Host ("  {0,-36} lost {1,5}%  avg {2,4} ms  worst {3,5} ms" -f $labels[$k], $s.lossPct, $s.avg, $s.max) }
Write-Host ("  Problem moments: home {0}, router-to-unit {1}, provider {2}, provider lag spikes {3}, outages {4}" -f $counts.home, $counts.upstream, $counts.provider, $counts.providerSpike, $outages.Count)
Write-Host "Report: $outPath"
