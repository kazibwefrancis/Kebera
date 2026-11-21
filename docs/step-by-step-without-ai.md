# Diagnose your internet step by step (no AI needed)

About 20 minutes. Write your answers down as you go; a phone notes app is fine.
Kebera is **not a hacking tool**: do this only on your own connection.

---

## Step 1: Is it every device, or just one?

- **Just one device** → the problem is probably that device (restart it, forget and
  re-join the Wi-Fi, update it). Stop here if that fixes it.
- **Every device** → continue.

Also try your phone **on mobile data** (Wi-Fi off). If mobile data works well while
home internet doesn't, the problem is in the home equipment or home service.

## Step 2: Easiest: run the Kebera check-up (Windows)

1. Download Kebera: **github.com/kazibwefrancis/kebera**, then green **Code** → **Download ZIP**, and unzip it.
2. Double-click **kebera.bat** and choose **1** (standard) or **2** (quick).
3. Read the **Verdict** at the top of the report that opens. It tells you where the
   problem is and what to do. `message-to-provider.txt` is ready to send.

If you can't download it, do Steps 3–6 by hand.

## Step 3: Find your router's address

Press the **Windows key**, type **PowerShell**, press **Enter**. Copy this line, right-click
in the window to paste it, and press **Enter**:

```
Get-NetIPConfiguration | ? IPv4DefaultGateway | % { 'Router: ' + $_.IPv4DefaultGateway.NextHop }
```

Write down the router address (for example `192.168.8.1`).

## Step 4: Find the next device (outdoor unit or fibre modem)

```
tracert -d -h 6 8.8.8.8
```

Line **1** is your router. If line **2** starts with `10.`, `172.`, `192.168.` or
`100.` and shows small times (under 10 ms), it's probably your **outdoor unit or
fibre modem**. Write it down.

## Step 5: The stability test (the most important step)

Put your router address (and the line-2 address, if you have one) into this command,
then paste it. It takes about 1 minute:

```
$router='192.168.8.1'; $next=''; $t=@{Router=$router;Google='8.8.8.8';Cloudflare='1.1.1.1'}; if($next){$t['Next device']=$next}; $r=@{}; foreach($k in $t.Keys){$r[$k]=@()}; 1..60|%{ foreach($k in @($t.Keys)){ $p=(New-Object Net.NetworkInformation.Ping).Send($t[$k],1500); if($p.Status -eq 'Success'){$r[$k]+=[int]$p.RoundtripTime}else{$r[$k]+=-1} }; Start-Sleep -m 400 }; foreach($k in $t.Keys){$ok=@($r[$k]|?{$_ -ge 0}); $j=0; for($i=1;$i -lt $ok.Count;$i++){$j+=[math]::Abs($ok[$i]-$ok[$i-1])}; '{0,-12} lost {1}/60  avg {2} ms  worst {3} ms  jitter {4} ms' -f $k,(60-$ok.Count),[math]::Round(($ok|measure -Average).Average),($ok|measure -Maximum).Maximum,[math]::Round($j/[math]::Max(1,$ok.Count-1))}
```

### Read the result

| What you see | Where the problem is | What to do |
|---|---|---|
| **Router** loses several, or worst over 100 ms often | Inside your home (Wi-Fi/router) | Move closer, use the 5 GHz network, change Wi-Fi channel, restart the router |
| Router fine, **Next device** loses some | Cable/power to the outdoor unit or modem, or the unit | Check the cable and power adapter, look for water damage, restart the unit |
| Router and next device fine, **Google and Cloudflare** both lose some, or worst over 300 ms, or jitter over 30 ms | The provider's network | Contact the provider (Step 8) |
| Everything near 0 lost, internet average under 80 ms | Looks healthy right now | Repeat at the bad time (e.g. evening) |

> If the **router** loses a few but **Google** loses fewer, your router is just
> ignoring pings. That's harmless.

## Step 6: Wi-Fi check (if on Wi-Fi)

```
netsh wlan show interfaces
```

- **Signal** under 40%: move closer to the router or use a cable.
- **Band 2.4 GHz** and your router also offers 5 GHz: switch to the 5 GHz network for nearby devices.

```
netsh wlan show networks mode=bssid | Select-String '^SSID|Signal|Channel |Band'
```

If 2 or more strong (50%+) networks share your 2.4 GHz channel, change your router's
2.4 GHz channel to whichever of **1, 6 or 11** is least used.

## Step 7: Look at your equipment's own pages

1. Open your router address in a browser (e.g. `http://192.168.8.1`), and the
   line-2 address if you have an outdoor unit or modem.
2. Sign in with the password on the label under the device (unless you changed it).
3. Find **Device information / Network information / Signal** and note:

| Reading | Good | Problem |
|---|---|---|
| RSRP (strength) | −90 or higher (e.g. −70) | below −100 |
| SINR (quality) | 13 or more | below 5 |
| RSRQ | −10 or higher | below −15 |
| Fibre Rx power | −8 to −25 dBm | below −27 dBm, or a red LOS light |

- **Strong RSRP but poor SINR** → a busy tower or interference: provider side.
- **Weak RSRP** → move the router to a window or higher up, or ask for the outdoor unit to be re-aimed.
- Look for **Data usage** (this month) and **Logs**: drops at the same time every
  day, or restarts you didn't do (often power cuts: consider a small UPS).

**Don't** press Restart/Reset or change APN, network mode or firmware.

## Going deeper (optional, for the curious)

These extra checks turn "probably" into "certainly". Do any that apply.

**A. Test at the bad time.** Problems often appear in the evening. Repeat Step 5 at
the time the internet is worst, and compare it with a good time.

**B. Longer stability test.** In the Step 5 command, change `1..60` to `1..600`
(about 10 minutes). Short tests miss problems that come and go.

**C. The 3-hour log** (if you downloaded Kebera): double-click `kebera.bat` → choose **3**.
It shows outages and the worst hours.

**D. Check the next device separately.** If Step 5 showed loss to the internet, confirm
that your outdoor unit or modem was fine at the same moments:

```
ping -n 200 NEXT_DEVICE_ADDRESS
```

0% loss there, with loss to the internet, means the problem is beyond your equipment.

**E. Take signal readings several times.** On the equipment's signal page (Step 7),
note RSRP and SINR **3 times, a minute apart**, and again in the evening. Quality that
drops in the evening points to a busy tower.

**F. The interference check (4G).** Using one 4G band's numbers:

| Bandwidth | Add to RSRP |
|---|---|
| 5 MHz | +24.8 |
| 10 MHz | +27.8 |
| 15 MHz | +29.5 |
| 20 MHz | +30.8 |

Expected RSSI = RSRP + the number above. If the measured RSSI is **6 or more higher**
than expected, something else may be interfering. If it's about the same or lower,
the noise is from the tower being busy, not jamming.
[More detail](interference-and-jamming.md).

**G. Read the equipment's logs.** Many outdoor units keep a week of events (e.g. ZTE:
*System Settings → Key Log Information*). Look for:
- the connection dropping at the **same time each day** (the provider resets the session daily)
- lines dated **2000-01-01** or restarts you didn't do (often **power cuts**: consider a UPS)
- cable "plug-out" events (check the cable and power to the outdoor unit)

**Don't** press Restart or Reset on that page.

**H. Rule out one device.** Test with a second device (another laptop, or a phone's
speed test) at the same moment. If both are bad, it isn't the device.

## Step 8: Write your detailed report

Copy [`templates/diagnosis-report.md`](../templates/diagnosis-report.md) into a
document and fill it in with your results from Steps 1–7 (and "Going deeper" if you
did it). Replace each [bracket]; write "not checked" where you skipped something.

This report is your evidence. It shows exactly what you tested, what was healthy,
and where the problem is. Attach it when you contact or escalate with your provider.

## Step 9: Contact your provider

Use the template in `templates/message-whatsapp.md` (or the one below). Fill in your numbers:

> Hello [Provider], my home internet (line [number]) keeps [dropping / lagging] on all
> my devices. My own router and equipment test fine ([x]% loss), but the internet
> beyond them loses [y]% with delays up to [z] ms. Signal at my unit: RSRP [a], SINR [b].
> Please check the tower/line serving my area, tell me if my line is being limited
> (I've used [n] GB this month), and send me a reference number. Thank you.

Not resolved? Escalate step by step with your provider: `templates/escalation.md`.
