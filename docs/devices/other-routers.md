# Other routers and antennas

## Your own Wi-Fi router (TP-Link, Tenda, Mercusys, Netgear, D-Link, ASUS, …)

Many people add their own router behind the provider's equipment. Kebera then sees:

- **Your router**: your own Wi-Fi router (e.g. `192.168.0.1`).
- **Next device**: the provider's router, outdoor unit or ONT.

Two routers both handing out addresses ("double NAT") works for browsing but can
cause **Strict NAT** on consoles. Where the provider unit offers **bridge mode**,
using it (or your router's "access point mode") avoids that. Change modes only
if you know how to undo it.

Where to look on most consumer routers:

- **Status / Network map**: WAN IP, uptime, connected devices.
- **Wireless**: channel (2.4 GHz: use 1, 6 or 11), channel width, band names.
- **System log**: frequent "WAN down/up" entries confirm drops on the provider side.

## MikroTik

Common with small ISPs and offices. **WinBox** or the web interface (WebFig) shows
interface traffic, logs and, for wireless models, signal (dBm) and CCQ. Leave
configuration to whoever set it up.

## Wireless ISP antennas (Ubiquiti, Cambium, MikroTik)

The antenna on your roof that points at the ISP's tower may have a web page
(Ubiquiti AirOS, Cambium ePMP). Useful readings:

| Reading | Good | Problem |
|---|---|---|
| Signal (dBm) | −45 to −65 | below −75 |
| Noise floor (dBm) | below −90 | above −85 (interference) |
| CCQ / link quality | above 90% | below 70% |

Problems are usually alignment, obstruction (trees grow), rain or a failing PoE
power adapter. The ISP should realign or replace equipment.

## Starlink

Use the Starlink app: **Statistics** (outages, their causes) and **Obstructions**
(a map of what blocks the view of the sky). Kebera's ping tests work normally on a
computer connected to Starlink Wi-Fi.
