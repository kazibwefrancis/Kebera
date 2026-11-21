# Device guides

How Kebera recognises equipment, and where each make keeps its useful readings.

## How identification works

Kebera only does what your browser does when you open your router's address:

1. It opens the device's normal web page (`http://<router address>/`) and looks
   for the maker's name or logo in the page (ZTE, Huawei, TP-Link, MikroTik, …)
   and provider branding (Airtel, MTN, …).
2. For ZTE and Huawei it asks the standard status interface the web page itself
   uses before you log in. Many devices answer with their model and firmware
   name; some also share signal readings.
3. A second device with its own web page right after your router is almost
   always an outdoor unit or fibre modem.

No logins, no password guessing, no settings changed.

If Kebera can't identify your device, look at the **label underneath it** (brand
and model) and tell your agent, or add it via a GitHub issue.

## Guides

| Make | Common in Uganda as | Guide |
|---|---|---|
| ZTE | Airtel and MTN 4G/5G indoor routers and outdoor units, MiFi | [zte.md](zte.md) |
| Huawei | 4G/5G routers (B-series), MiFi (E-series), fibre ONTs | [huawei.md](huawei.md) |
| Fibre modems (Huawei, ZTE, Nokia, FiberHome) | Fibre to the home | [fibre-onts.md](fibre-onts.md) |
| TP-Link, Tenda, MikroTik, Ubiquiti, Cambium and others | Own Wi-Fi routers, wireless ISP antennas | [other-routers.md](other-routers.md) |

## Tested so far

| Device | Role | Provider | Status |
|---|---|---|---|
| ZTE MF296A | Indoor router | Airtel | Identified automatically (model, firmware, provider) |
| ZTE G5FA | 5G outdoor unit | Airtel | Identified as ZTE outdoor unit; signal read from its status page in a browser |

Please add yours: open an issue with the **Device report** template.
