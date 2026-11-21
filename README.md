<p align="center">
  <img src="docs/images/banner.svg" alt="Kebera: find out where your internet problem really is" width="100%">
</p>

<p align="center">
  <b>Kebera</b> (Luganda: <i>examine, inspect</i>) is a free, open-source internet check-up for home users.<br>
  It tells you <b>where</b> your internet problem really is (your device, your Wi-Fi, your router, your outdoor unit or fibre modem, or your provider) and writes a report you can send them.
</p>

<p align="center">
  <a href="LICENSE"><img alt="MIT licence" src="https://img.shields.io/badge/licence-MIT-green"></a>
  <img alt="Windows" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6">
  <img alt="macOS and Linux beta" src="https://img.shields.io/badge/macOS%20%7C%20Linux-beta-lightgrey">
  <img alt="Read-only" src="https://img.shields.io/badge/read--only-no%20settings%20changed-blue">
</p>

---

## Why

"Restart your router." "Switch it off and on." "We'll call you back."

When home internet in Uganda is slow or keeps dropping, it's hard to prove where
the problem is, so the conversation with the provider goes nowhere. Kebera gives
you evidence in plain language:

> **The main problem is on your internet provider's side.** Your devices, Wi-Fi
> and router stayed healthy while the connection beyond them dropped or lagged.

…plus the numbers behind it, what you can fix yourself, and a ready-to-send
WhatsApp or email message for your provider.

It works on its own, and it works even better with an AI coding agent (Claude
Code, ChatGPT Codex, Gemini CLI, Cursor, Grok and others). The agent follows
[`AGENTS.md`](AGENTS.md) to read your router and outdoor unit pages *after you
sign in*, explain the signal readings, and talk you through the results.

## How it works

<p align="center">
  <img src="docs/images/how-it-works.svg" alt="Kebera pings your router, the next device and two internet servers at the same moment. The first link that fails is where the problem is." width="100%">
</p>

Kebera checks every link of your connection **at the same moment**, twice a
second, so it can tell which link failed first:

| If this fails first | The problem is | Who fixes it |
|---|---|---|
| Your router | Wi-Fi or router inside your home | You (often free and quick) |
| The outdoor unit / fibre modem | That unit, its cable or power | You or the provider |
| The internet (Google **and** Cloudflare) | The provider's network | The provider |

## What it checks

| Area | Checks |
|---|---|
| **Your computer** | Wired or Wi-Fi, adapter, Wi-Fi signal, band (2.4/5 GHz), channel, link speed |
| **Wi-Fi neighbourhood** | Nearby networks, strong neighbours on your channel, the best channel to use, whether your router's 5 GHz is available |
| **Your equipment** | Identifies the router and the device behind it (ZTE, Huawei, TP-Link, MikroTik, Nokia, FiberHome and more) from the pages they already show; reads model, firmware, provider branding, and mobile signal where shared without a login |
| **Stability** | Loss, delay, worst case and jitter on every link at the same moment; counts *where* each failure happened |
| **Mobile signal** | Grades RSRP (strength), SINR and RSRQ (quality); tells "strong but noisy" (busy cell) from "weak" (placement) |
| **Interference and jamming** | Wi-Fi channel crowding; for 4G, the RSSI-vs-RSRP check that separates a busy cell from external interference ([guide](docs/interference-and-jamming.md)) |
| **Speed** | Download and upload (optional, about 30 MB) |
| **DNS** | Your current DNS against Cloudflare 1.1.1.1 and Google 8.8.8.8 |
| **Shared address (CGNAT)** | Whether your provider shares one public IP between customers (the usual cause of Strict NAT on Xbox and PlayStation) |
| **Long logger** | Records every 5 s for hours to catch drops that come and go, then reports outages, lag spikes and the worst hours |

Works with **outdoor + indoor 5G/4G units, indoor 4G routers, MiFi, fibre,
wireless ISPs and Starlink**. See [which connection do you have?](docs/connection-types.md)

## The report

<p align="center">
  <img src="docs/images/report-preview.svg" alt="Example Kebera report with a verdict, findings and a stability table" width="80%">
</p>

Every run saves a folder in `reports/` containing:

| File | What it's for |
|---|---|
| `report.html` | Opens in your browser: verdict, findings, tables |
| `report.md` | The same report as text, easy to paste |
| `message-to-provider.txt` | A ready-to-send complaint draft with your results filled in |
| `report.json` | Full data for AI agents and other tools |

Neighbours' Wi-Fi names, MAC addresses, SIM/IMEI numbers and your full public IP
are **left out**. See [PRIVACY.md](PRIVACY.md).

## Quick start

### Option A: Windows, no AI needed

1. **Download:** click the green **Code** button above, then **Download ZIP**, and unzip it anywhere
   (or `git clone https://github.com/kazibwefrancis/kebera.git`).
2. **Double-click `kebera.bat`** and choose:
   - `1`: standard check (about 5 minutes)
   - `2`: quick check (about 2 minutes)
   - `3`: long log (3 hours)
3. Your report opens in the browser when it finishes.

Or from PowerShell in the Kebera folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera.ps1
```

Options: `-Quick`, `-NoSpeedTest` (saves data), `-NoInternetServices`, `-PingRounds 200`.

Long log for problems that come and go:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera-log.ps1 -Hours 3
```

### Option B: with an AI coding agent (recommended)

1. Download Kebera (as above) and open the folder in your agent, for example
   Claude Code, Codex CLI, Gemini CLI, Cursor or VS Code with Copilot agent mode.
2. Say: **"Diagnose my internet."**
3. The agent reads [`AGENTS.md`](AGENTS.md), asks you a few questions, runs the
   check-up and explains the results. If it can use a browser, it will open your
   router and outdoor unit pages. **You sign in yourself**; the agent never
   handles your passwords. It then reads the signal and status, and writes your
   message to the provider.

### Option C: macOS or Linux (beta)

```bash
bash scripts/unix/kebera.sh            # add --quick or --no-speedtest
```

## Safe by design

- **Read-only:** no settings changed, no logins, no password guessing, nothing
  installed. Kebera only opens the same pages your browser does.
- **Your network only:** it never probes other people's devices.
- **Private:** everything stays on your computer. The only outside services are
  the ping/DNS targets, an IP-lookup service and the optional speed test
  ([details](PRIVACY.md)).
- **Neutral:** it measures; it doesn't take sides. Not affiliated with any
  provider or manufacturer ([disclaimer](DISCLAIMER.md)).

## Real example

The case that started Kebera: "the router is the problem". Every device was
slow, and the checks showed the home network and the 5G outdoor unit were
healthy. The 4G anchor cell was congested (strong signal, poor SINR) and the
drops happened on the provider's side. Moving devices to 5 GHz Wi-Fi also cut the
laptop's delay to the router from up to 58 ms to about 2 ms.
[Read the case study](examples/case-study-kampala-5g.md).

## Guides

- [Interpreting the results](docs/interpreting-results.md): every threshold explained
- [Which connection do you have?](docs/connection-types.md)
- [Interference and jamming](docs/interference-and-jamming.md)
- [Device guides](docs/devices/README.md): ZTE, Huawei, fibre modems, other routers
- [Working with your provider](docs/providers.md)
- Message templates: [WhatsApp](templates/message-whatsapp.md) · [Email](templates/message-email.md) · [Escalating to UCC](templates/escalation-ucc.md)

## FAQ

**Do I need an AI agent?** No. The scripts produce a full report on their own. An
agent adds the equipment-page readings and a conversation about the results.

**Will it use a lot of data?** About 35 MB for the standard check with speed test,
12 MB in quick mode, or under 1 MB with `-NoSpeedTest`.

**Windows says scripts are disabled.** Use `kebera.bat` or the
`-ExecutionPolicy Bypass` command above. It only applies to that one run.

**It found no Wi-Fi networks.** On Windows 11, Wi-Fi scanning may need Location
on: *Settings > Privacy & security > Location*.

**My router wasn't identified.** Look at the label underneath for the brand and model,
tell your agent, and please [open a device report](../../issues/new?template=device-report.md)
so Kebera recognises it next time.

**Windows in another language?** Some Wi-Fi details are read from English
Windows output. Other languages still get the ping, route, DNS and speed results.
Translations of the parsers are welcome.

## Contributing

Kebera gets better with every router, outdoor unit and fibre modem people report.
See [CONTRIBUTING.md](CONTRIBUTING.md). Device reports, translations (Luganda,
Swahili, Runyankole and others) and testing on macOS/Linux are especially welcome.

## Licence

[MIT](LICENSE) © 2026 Kazibwe Francis. Free to use, share and improve.
