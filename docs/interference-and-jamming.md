# Interference and jamming

"Is something jamming my signal?" is a common worry. Kebera can tell you whether
the evidence points that way. Real jamming is **rare**; a busy network or
neighbours' Wi-Fi is far more common. Here is how to tell them apart.

## Two different airwaves

1. **Wi-Fi inside your home** (2.4 GHz and 5 GHz): affected by neighbours' Wi-Fi,
   microwaves, Bluetooth, cordless phones, baby monitors and walls.
2. **The mobile link** between your router/outdoor unit and the tower
   (4G/5G bands): household gadgets do **not** affect it. It is affected by
   distance, obstacles, the number of other users on the cell and interference
   from other transmitters.

## Wi-Fi interference: what Kebera checks

- **How many strong networks share or overlap your channel.** On 2.4 GHz,
  channels within 4 of each other overlap. Two or more strong neighbours on
  your channel will slow you down.
- **Channel utilization** (if your router reports it): above 60% means the
  channel is busy most of the time.
- **Signal-to-noise** (macOS only): below 15–20 dB suggests non-Wi-Fi noise.
- **Strong signal but poor results** (high delay or loss to the router despite
  70%+ signal) hints at interference rather than distance.

Fixes: use 5 GHz, switch 2.4 GHz to the least crowded of channels 1/6/11, move the
router away from microwaves and thick walls.

## Mobile-link interference: the RSSI check

Your equipment reports four numbers per band: RSRP, RSRQ, SINR and RSSI. For
**4G (LTE)** you can check whether the total power (RSSI) is more than the
signal itself can explain:

```
expected RSSI (fully loaded cell) ≈ RSRP + 10 × log10(12 × number_of_resource_blocks)

resource blocks: 5 MHz = 25, 10 MHz = 50, 15 MHz = 75, 20 MHz = 100
so add:          5 MHz +24.8 dB, 10 MHz +27.8 dB, 15 MHz +29.5 dB, 20 MHz +30.8 dB
```

| Measured RSSI vs expected | Meaning |
|---|---|
| Lower or about equal | Normal. Noise is from the network's own traffic: a **busy cell**, not jamming. |
| 6 dB or more **higher** | Extra power from something else: **external interference** is possible. |

**Worked example (real case, Kampala, Nov 2026).** Band 7, 20 MHz, RSRP −66 dBm:
expected RSSI ≈ −66 + 30.8 = **−35 dBm**. Measured: **−37 to −39 dBm**. That's within
the expected range, so no external interference. SINR was only 6–8 dB and RSRQ
−11 to −14 dB because the cell was busy. Meanwhile the 5G band had a clean SINR
of 12–14 dB. Conclusion: congestion, not jamming.

## Signs that point to jamming (rare)

- Signal **quality collapses on every band at once**, 4G **and** 5G, often to "no
  service", while strength (RSRP) stays the same or the unit cannot register.
- RSSI rises well above what RSRP predicts (check above) on several bands.
- Phones nearby lose signal at the same moments.
- It is tied to a place or a time (for example only during certain hours near
  a particular building).

Signs that point to **congestion** instead:

- Worse in the **evenings** and better late at night or early morning.
- Only one or two bands look noisy; another band (often 5G) stays clean.
- RSSI is consistent with RSRP and bandwidth.

## What to do if you suspect interference

1. Collect evidence: Kebera reports from different times of day, and the equipment's
   signal readings at good and bad moments (photos are fine; cover the SIM/IMEI numbers).
2. Report to your provider first; they can see the cell's interference levels.
3. If the provider confirms external interference and cannot resolve it, it is the
   regulator's job: the **Uganda Communications Commission (UCC)** handles radio
   interference. See `templates/escalation-ucc.md`.

Never try to locate or confront a suspected source yourself, and never use any
device that transmits on mobile frequencies. Signal boosters and jammers are
regulated, and unapproved ones are illegal and can cause the very problems
described here.
