# ZTE equipment

ZTE makes much of the 4G/5G home equipment used by Ugandan mobile providers:
indoor routers (often model names starting **MF** or **MC**), 5G outdoor units
and MiFi hotspots. Firmware is usually provider-branded (the version string
often contains the provider name, e.g. `CR_AIRTELMF296AV1.0.0B01`).

## Finding the page

- Usually `http://192.168.0.1`, `http://192.168.8.1` or another address. Kebera shows
  it as "Your router" in the report.
- An **outdoor unit** behind an indoor router has its own address. Kebera shows it as
  "the next device" (e.g. `10.x.x.x`). Its page may use HTTPS with a self-signed
  certificate; your browser will warn you. That is normal for home equipment.
- The login password is on the label under the device unless someone changed it.
  **Type it yourself.** Never give it to an agent.

## What Kebera reads without a login

ZTE web pages use a status interface at `/goform/goform_get_cmd_process`. Before
login, many units still return the **model name** and **firmware version**. Some
also return signal values; many return blanks until you log in.

> Many ZTE units report `modem_undetected` / `ppp_disconnected` when nobody is
> logged in, even when the internet works fine. Kebera ignores those two values.

## Where the useful readings are (after you log in)

### Indoor router (e.g. MF296A)

- **Home page:** connected devices count, internet status.
- **Detail information / Status information:** WAN IP. A private WAN IP (10.x,
  100.64–127.x) means the provider shares public addresses (CGNAT).
- **Wi-Fi > Settings:** **Single SSID** merges 2.4 and 5 GHz under one name.
  Disabling it gives each band its own name (the 5 GHz one usually gets a `_5G`
  suffix). Reversible.
- **Connection Mode:** with an outdoor unit, the indoor router usually gets its
  internet over the cable (DHCP).

### 5G outdoor unit (e.g. Airtel ZTE G5FA)

- **Home:** network type (4G/5G), **connection timer** (how long the link to the
  provider has stayed up; a reset means it reconnected), live upload/download.
- **More Detail / Device Information > Network Information:** per-band table
  with **PCI, band, frequency, bandwidth, RSRP, RSRQ, SINR, RSSI** for the 4G
  primary (PCC), secondary carriers (SCC) and the 5G carrier, plus cell ID.
  The table refreshes on its own; sample it several times.
- **System > Diagnosis:** SIM status, registration, connection, work mode
  (e.g. Bridge Mode), APN and **data used**.
- **Data Usage:** monthly usage. Useful when asking about fair-usage limits.
- **Install Helper** (app link on the home page): helps aim the unit.
- **System > System Settings > Key Log Information**: about a week of events.
  This is the most useful page for problems that come and go. **Read only**: the
  same page has Restart and Reset buttons. Don't touch them. What the lines mean:

  | Log line | Meaning |
  |---|---|
  | `last_domain 2, cur_domain 0` with `cur_srv 1` and `rsrp= 0` | Lost registration with the network: a real **drop** |
  | Same drop at the **same clock time ~24 h apart** | The provider resets the data session every 24 hours (common). The time moves after each reboot. |
  | `[DATA] ... dst_clear_type` about once an hour | Routine data-session housekeeping; usually harmless |
  | `port[eth0] plug-out` / `plug-in` | The cable link to the indoor router went down and up (after a drop, a reboot, a cable fault or power to the indoor router) |
  | Lines dated `2000-01-01` | The unit **restarted** and hadn't set its clock yet. If you didn't restart it, suspect a **power cut** or a faulty power adapter or PoE injector. |
  | `last_srv 13, cur_srv 14` and back | 4G ↔ 5G (NSA) leg added or released. Frequent switching, especially when idle, is mostly normal. |
  | `stat=..., NSA 4g rsrp=..., rsrq=..., sinr=...` | Periodic signal snapshot: a week of RSRP/RSRQ/SINR history |
  | `forbid wan ping`, `user login` | Security and admin events; not faults |

  A practical tip: if a 24-hour reset hits at a bad time, a scheduled daily restart
  at a quiet hour (e.g. 03:00) moves it to night time. Only change this if you
  want to; it's under Scheduled Restart on the same page.

Leave alone unless you know why: APN, network mode, bridge/router mode, firmware
update, the connection on/off switch on the home page.

## Known model notes

| Model | Role | Notes |
|---|---|---|
| MF296A | Indoor 4G/5G CPE (Wi-Fi) | Airtel-branded firmware seen. Has Single SSID option. |
| G5FA | 5G outdoor unit | Airtel-branded firmware seen. 5G NSA: shows 4G anchor + 5G (n78) carrier. Bridge mode by default. |

Please add models you meet (with identifiers removed) through a Device report issue.
