# Kebera: instructions for AI agents

You are helping someone in Uganda (or anywhere) find out **where** their home
internet problem really is (their device, Wi-Fi, router, outdoor unit or fibre
modem, or their internet provider) and give them a clear report they can act on
or send to their provider.

These instructions work for any coding agent that can run commands (Claude Code,
Codex, Cursor, Gemini CLI, Copilot agent mode and others). Read the whole file
before starting.

---

## 1. Ground rules (always follow)

1. **Read-only by default.** Run the Kebera scripts and read pages. Do **not**
   change router, outdoor unit, computer or account settings unless the person
   explicitly asks for that specific change *after* you have explained what it
   does and how to undo it.
2. **Never handle passwords.** Never type, guess, store or ask the person to paste
   a router, Wi-Fi or account password. If a page needs a login, ask the person
   to sign in themselves (in the browser you share, or in their own browser) and
   tell you when they are done.
3. **Never try default credentials, bypass a login, or exploit anything.** Only
   read what the device shows openly or what the person shows you after signing
   in. Kebera is a diagnostic tool, not a hacking tool. See `DISCLAIMER.md`.
4. **Only the person's own network.** Do not scan or probe other people's
   networks or devices. Listing nearby Wi-Fi names (which every phone does) is
   fine; keep neighbour names out of anything shared.
5. **Protect identifiers.** Never put SIM numbers, IMEI/IMSI, MAC addresses,
   Wi-Fi passwords, account numbers or full public IP addresses in reports,
   messages or anything sent outside the computer. Kebera already masks them;
   keep it that way.
6. **Be honest about uncertainty.** A short test can miss intermittent problems.
   Say what you measured and what you could not check. Do not blame a provider
   without evidence, and do not dismiss one when the evidence points at them.
7. **Plain language.** The person may not be technical. Explain results the way
   you would to a friend, then give the numbers for anyone who wants them.
8. **Data costs money.** Ask before running the speed test on metered data
   (it uses about 35 MB, or 12 MB with `-Quick`). Use `-NoSpeedTest` if they say no.

---

## 2. The diagnosis flow

### Step 1: Ask a few questions (keep it short)

- Which provider (Airtel, MTN, Lyca, Roke, a fibre company, Starlink, other)?
- What equipment? Point them to `docs/connection-types.md` if unsure. Common setups:
  - **Outdoor unit + indoor router** (4G/5G "ODU" on the wall or roof, cable to a router inside)
  - **Indoor 4G/5G router only** (SIM inside the router)
  - **MiFi / pocket hotspot**
  - **Fibre** (a fibre modem/ONT, often with a separate Wi-Fi router)
  - **Wireless ISP** (a dish/antenna pointing at a tower, run by a local ISP)
  - **Starlink**
- What is the problem: slow, drops completely, lag in games/calls, only some devices, certain times of day?
- Does it affect **all devices** or just one? (All devices points away from a single device.)

If they know the router's model or the label under it (for example "ZTE MF296A",
"Huawei B535", "ZTE G5FA"), note it. Check `docs/devices/` for that make.

### Step 2: Run the check-up

Windows (from the repo folder):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera.ps1
```

macOS / Linux (beta):

```bash
bash scripts/unix/kebera.sh
```

Options: `-Quick` (about 2 min), `-NoSpeedTest`, `-NoInternetServices`.
The script prints progress and saves `reports/<date_time>/` with:

| File | Use |
|---|---|
| `report.json` | Full structured data. **Read this first.** |
| `report.md` / `report.html` | Human-readable report |
| `message-to-provider.txt` | Draft complaint |

### Step 3: Read `report.json`

Key fields:

- `connection`: wired or Wi-Fi, gateway (router) IP, DNS servers.
- `wifi`, `wifiNeighbourhood.summary`: signal %, band, channel, how many strong
  neighbours overlap the channel, suggested 2.4 GHz channel, whether the router's
  own 5 GHz network is visible.
- `devices[]`: what Kebera could identify about the router (`gateway`) and the
  next device after it (`upstream`), such as vendor, model, role, provider, and
  sometimes mobile signal readings (`cellular`, `cellGrades`) if the device shares
  them without a login.
- `stability.stats`: loss, average, worst, jitter for each link, measured **at
  the same moment**. `stability.events` counts *where* each failure happened:
  - `homeDrops`: the router did not answer, so the problem is inside the home
  - `upstreamDrops`: the router answered but the next device did not, so the problem is between the router and the outdoor unit/modem
  - `providerDrops`: all the person's equipment answered but Google **and** Cloudflare did not, so the problem is in the provider network
  - `providerSpikes`: the home was fast but the internet delay was over 300 ms
- `dns.results`, `speed`, `address.cgnat`, `findings[]`, `verdict`.

### Step 4: Look at the equipment pages (if you can drive a browser)

The equipment's own status pages hold the most useful readings (mobile signal,
fibre light level, uptime, data used). Kebera's script cannot read pages that
need a login, but you can, **after the person signs in**:

1. Open the router page (`connection.gateway`, e.g. `http://192.168.8.1`) and,
   if there is one, the next device (`devices[1].ip`, often an outdoor unit).
2. If you see a login page, stop and ask the person to sign in.
3. Read, do not change. Typical places:
   - **Device information / Network information / Status**: signal (RSRP,
     RSRQ, SINR, RSSI), band, cell ID, connection uptime
   - **Diagnosis**: built-in checks on some ZTE units
   - **Data usage / Statistics**: monthly usage (relevant to fair-usage limits)
   - **Fibre ONT: Optical / PON info**: Rx optical power (dBm)
4. If the page has a refreshing table, sample it several times over 1–2 minutes;
   signal quality changes from moment to moment.

See `docs/devices/` for where these live on ZTE, Huawei and fibre modems.

If you cannot drive a browser, ask the person to open those pages and read out
or screenshot the values (with the SIM/IMEI numbers covered).

### Step 5: Interpret

Use `docs/interpreting-results.md` for thresholds. The core logic:

| What you see | Where the problem is |
|---|---|
| Loss or big delays to the **router** (and also beyond) | Home Wi-Fi or router |
| Router loss but **next device has less loss** | Harmless: router just answers pings last |
| Router fine, **next device** loses replies | Cable/power to outdoor unit or modem, or the unit itself |
| All own equipment fine, **internet** loses replies or spikes | Provider network |
| Strong mobile signal (RSRP) but poor quality (SINR/RSRQ) | Busy cell or interference (provider side); re-aiming may help |
| Weak RSRP | Placement/aiming of the unit or router; coverage |
| Fibre Rx power below about −27 dBm | Fibre line or connector problem (provider side) |
| Fast speed test but laggy | Congestion/jitter, not raw speed |
| Good everything during test, problems "sometimes" | Run the long logger (Step 6) |

**Jamming and interference:** see `docs/interference-and-jamming.md`. Real
jamming is rare and affects **every band at once** (signal quality collapses on
4G *and* 5G together, often to no service). A busy cell looks different: one or
two bands are noisy, and RSSI matches what the RSRP and bandwidth predict. Use
the RSSI-vs-RSRP check in that document before suggesting interference.

### Step 6: Catch problems that come and go

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera-log.ps1 -Hours 3
```

It pings every 5 s and analyses itself at the end (`*-report.md` next to the CSV).
To analyse a log at any time:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\kebera-analyze-log.ps1 -LogFile .\reports\kebera-log_<...>.csv
```

Remind the person to keep the computer plugged in and awake. If the agent
session might end, suggest they run the logger in their own PowerShell window so
it is not tied to the agent.

If an outdoor unit shows a **connection timer**, note it at the start and the end.
A reset during the log means the link to the provider dropped (or the unit restarted:
if pings to the unit also failed at that moment, suspect its power or cable).

### Step 7: Report back

Give the person:

1. **A one-line verdict.** For example: "Your equipment is fine. The drops are on Airtel's side."
2. **A short table** of what was checked and the result.
3. **What they can do themselves**, cheapest first (move router, 5 GHz, change
   channel, DNS, check cables).
4. **What the provider must do**, with a ready message. Start from
   `message-to-provider.txt` and `templates/`, add what you learned from the
   equipment pages, keep it short and polite, and **leave out identifiers**.
5. **What you could not check.**

Offer a WhatsApp-length version; most Ugandan providers handle complaints on WhatsApp.
If the provider does not resolve it, `templates/escalation-ucc.md` explains
escalating to the Uganda Communications Commission.

---

## 3. Making changes (only when asked)

If the person asks you to change something (Wi-Fi channel, splitting 2.4/5 GHz
names, DNS):

- Say exactly what will change, what might briefly disconnect, and how to undo it.
- Get a clear yes for that specific change.
- Make only that change. Do not touch admin passwords, firmware, APN, network
  mode or anything you were not asked about.
- Confirm afterwards that it worked, by re-running the relevant check.

Changes on the person's own computer that need administrator rights (driver
settings, for example) are best done by the person following your steps.

---

## 4. Contributing what you learn

If you met equipment that Kebera did not recognise, or a status page in a
different place, suggest the person opens an issue using the "Device report"
template (with identifiers removed), so the next person gets a better result.
