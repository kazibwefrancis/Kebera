# Interpreting the results

Kebera's thresholds in one place, in plain language. They are rules of thumb,
not laws of physics: use them together, not one number alone.

## The one idea that matters

Kebera pings several points **at the same moment**:

```
 This computer ──► Your router ──► Next device (outdoor unit / modem) ──► Provider ──► Internet
                    (ping 1)          (ping 2)                                         (ping 3, 4)
```

The first point that fails is where the problem is.

- Router fails → **inside your home** (Wi-Fi or router).
- Router fine, next device fails → **cable/power to the outdoor unit or modem, or the unit itself**.
- All your equipment fine, the internet fails → **the provider's network**.

Kebera pings **two** internet targets (Google 8.8.8.8 and Cloudflare 1.1.1.1) and
only counts an internet failure when **both** fail at once, so one busy server
cannot fool it.

> Routers often answer pings *to themselves* last when they are busy. If the
> router shows some loss but the device **after** it shows less, the router is
> fine: it is just ignoring pings, not dropping your traffic.

## Ping results

| Measure | Good | Watch | Problem |
|---|---|---|---|
| Loss to your router | 0% | under 1% | 3% or more |
| Delay to your router (Wi-Fi) | under 10 ms | 95% under 100 ms | frequent spikes above 100 ms |
| Delay to your router (cable) | 1–2 ms | — | over 10 ms |
| Loss to the internet | 0% | 1–2% | 2% or more beyond your equipment |
| Delay to the internet (Uganda) | under 80 ms | 80–150 ms | over 150 ms average |
| Jitter (delay variation) | under 10 ms | 20–40 ms | over 40 ms |

Jitter matters more than speed for calls and games. Above about 30 ms, voice
breaks up and games feel laggy even when a speed test looks fine.

## Wi-Fi

| Measure | Good | Watch | Problem |
|---|---|---|---|
| Signal (Windows %) | 70%+ | 40–70% | under 40% |
| Signal (macOS dBm) | above −60 | −60 to −75 | below −75 |
| Signal-to-noise (macOS) | 25 dB+ | 15–25 dB | under 15 dB |
| Strong neighbours on your 2.4 GHz channel | 0–1 | 2 | 3+ |

**2.4 GHz vs 5 GHz:** 5 GHz is faster and usually uncrowded, but reaches less far
through walls. In a small home, put nearby devices on 5 GHz. On 2.4 GHz, only
channels **1, 6 and 11** don't overlap; Kebera suggests the least crowded one.

## Mobile signal (4G/5G routers and outdoor units)

Read these from the equipment's status page ("Device information",
"Network information", "Signal").

| Reading | What it means | Excellent | Good | Fair | Poor |
|---|---|---|---|---|---|
| **RSRP** (dBm) | Signal **strength** | ≥ −80 | −80 to −90 | −90 to −100 | below −100 |
| **SINR** (dB) | Signal **quality** (signal vs noise and interference) | ≥ 20 | 13 to 20 | 5 to 13 | below 5 |
| **RSRQ** (dB) | Quality, affected by how busy the cell is | ≥ −10 | | −10 to −15 | below −15 |
| **RSSI** (dBm) | Total power received, including noise and other users | (used in the interference check) | | | |

How to read combinations:

| RSRP | SINR | Likely cause |
|---|---|---|
| Strong | Good | Signal is fine; look elsewhere |
| Strong | Poor | **Busy cell or interference**: provider side. Re-aiming an outdoor unit sometimes helps. |
| Weak | Poor | Placement or coverage: move the router to a window or higher up; aim the outdoor unit |
| Weak | Good | Far from the tower but clean; usually workable |

**5G in "NSA" mode** (most 5G home services today) leans on a 4G connection as its
anchor. If the 4G readings are poor, 5G can stall even with a strong 5G signal.
Always look at both.

## Fibre

| Optical receive power (Rx) | Meaning |
|---|---|
| −8 to −25 dBm | Healthy |
| −25 to −27 dBm | Weak; works but sensitive to dirt or bends |
| below −27 dBm | Problem with the fibre line or connector: provider must fix |
| "LOS" light red/flashing | Loss of signal: fibre is cut, unplugged or badly bent |

Never look into a fibre cable or port. The laser can damage your eyes.

## Speed

Compare with your plan. Kebera flags under 5 Mbps as a problem and under
10 Mbps as worth watching. A good speed **with** high jitter or loss still feels bad.

If your home network tests fine but speed is low, ask the provider whether your
line is limited (for example after a fair-usage threshold on "unlimited" bundles).

## DNS

DNS turns names (youtube.com) into addresses. A slow DNS makes **opening** sites and
apps slow but does not affect download speed or in-game lag. If your current DNS
averages 50 ms+ slower than 1.1.1.1 or 8.8.8.8, switch to those.

## Shared public address (CGNAT)

Most mobile/5G home services share one public address among many customers.
Everyday browsing is unaffected. It can make consoles report **Strict NAT** and
blocks port forwarding (hosting servers, some remote cameras). Only the provider
can fix it, by giving you a public IP, sometimes for a fee.
