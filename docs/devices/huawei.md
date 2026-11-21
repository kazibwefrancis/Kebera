# Huawei equipment

Huawei 4G/5G routers (often **B**-series, e.g. B310, B315, B535, B618), MiFi
hotspots (**E**-series) and 5G CPEs use the "HiLink" web interface. Huawei
**EchoLife** boxes are fibre modems; see [fibre-onts.md](fibre-onts.md).

## Finding the page

- Usually `http://192.168.8.1` (sometimes `192.168.1.1` or `192.168.3.1`).
- Default password on the label under the device unless changed. **Type it yourself.**

## What Kebera reads without a login

HiLink pages use an API under `/api/...`. Before login the page asks for a
session token at `/api/webserver/SesTokInfo` (Kebera does the same, exactly as the
page does). Depending on firmware, these may answer without login:

- `/api/device/basic_information`: product name, software version
- `/api/monitoring/status`: connection status, network type, signal bars
- `/api/device/signal`: RSRP, RSRQ, SINR, RSSI, band, cell ID (often login-only)
- `/api/net/current-plmn`: operator name

If they need a login, Kebera simply records what it could see.

## Where the useful readings are (after you log in)

- **Advanced > System > Device Information**: RSRP, RSRQ, SINR, RSSI, band, cell ID
  (exact menu names vary by firmware).
- **Statistics**: data used this month.
- **Home**: connection status and network type (4G/4G+/5G).
- **Wi-Fi settings**: some models offer "5 GHz preferred" or "Wi-Fi 5G priority",
  which works like ZTE's Single SSID.

Leave alone unless you know why: APN/profile, network mode (e.g. forcing 4G only),
band locking, firmware update.

## Notes

- Huawei MiFi devices drop connections when overheating or on low battery.
- Indoor routers improve a lot when moved to a window or higher up.
