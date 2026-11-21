# Which kind of connection do you have?

Kebera works with all of these. Knowing which one you have helps you (or your AI
agent) look in the right place.

## 1. Outdoor unit + indoor router (4G/5G "home broadband")

```
 [Phone / laptop / TV] ~~Wi-Fi~~ [Indoor router] ───cable─── [Outdoor unit on wall/roof] ~~4G/5G~~ (Tower)
 [Xbox / PC] ───────cable─────────┘
```

- The **outdoor unit (ODU)** holds the SIM and talks to the tower. It often has
  its own web page (for example Airtel's ZTE 5G ODU).
- The **indoor router (IDU/CPE)** gives you Wi-Fi.
- Kebera usually sees the indoor router as "your router" and the outdoor unit as
  "the next device".
- Most useful readings: the outdoor unit's **RSRP/SINR/RSRQ** for 4G and 5G, its
  **connection uptime**, and **data used**.
- Typical problems: busy cell (strong signal, poor quality), unit badly aimed,
  water in the outdoor cable, faulty power adapter.

## 2. Indoor 4G/5G router only

```
 [Devices] ~~Wi-Fi~~ [Router with SIM inside] ~~4G/5G~~ (Tower)
```

- Examples: many ZTE MF-series and Huawei B-series routers.
- The router's status page shows the mobile signal.
- Placement matters a lot: near a window, as high as possible, away from metal.

## 3. MiFi / pocket hotspot

Like case 2 but battery powered, with weaker antennas and fewer devices supported.
Heat and low battery can cause drops. Keep it charged and ventilated.

## 4. Fibre (FTTH)

```
 [Devices] ~~Wi-Fi~~ [Wi-Fi router] ───cable─── [Fibre modem / ONT] ═══fibre═══ (Provider)
                      (sometimes the same box)
```

- The **ONT** converts light to network signal. Lights to know: **PON** (should be
  steady) and **LOS** (should be off; red means the fibre signal is lost).
- Most useful reading: **optical receive power (Rx)** on the ONT's status page.
- Typical problems: bent/damaged fibre, dirty connector, provider outage.

## 5. Wireless ISP (dish or panel pointed at a tower)

```
 [Devices] ~~Wi-Fi~~ [Router] ───cable─── [Antenna on roof] ~~radio link~~ (ISP tower)
```

- Common with local ISPs. The antenna (often Ubiquiti, Cambium or MikroTik) may
  have its own web page showing signal and link quality.
- Typical problems: alignment, trees/buildings blocking the path, rain fade,
  power (PoE) adapter faults.

## 6. Starlink

The Starlink app shows obstructions, outages and their cause. Run Kebera on a
computer connected to the Starlink Wi-Fi as usual. Obstructions (trees, walls)
are the most common cause of short drops.

## Not sure?

Look at the label under your router: brand and model (e.g. "ZTE MF296A",
"Huawei B535-333"). If a second box connects to it with a cable, that box is
likely the outdoor unit or fibre modem. Tell your agent what you see, or check
the "Your setup" section of the Kebera report.
