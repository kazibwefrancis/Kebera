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

Leave alone unless you know why: APN, network mode, bridge/router mode, firmware
update, the connection on/off switch on the home page.

## Known model notes

| Model | Role | Notes |
|---|---|---|
| MF296A | Indoor 4G/5G CPE (Wi-Fi) | Airtel-branded firmware seen. Has Single SSID option. |
| G5FA | 5G outdoor unit | Airtel-branded firmware seen. 5G NSA: shows 4G anchor + 5G (n78) carrier. Bridge mode by default. |

Please add models you meet (with identifiers removed) through a Device report issue.
