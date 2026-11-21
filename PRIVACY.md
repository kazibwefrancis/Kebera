# Privacy

Kebera runs entirely on your computer. There is no Kebera server, no account and
no tracking.

## What Kebera contacts

| Destination | Why | Can you turn it off? |
|---|---|---|
| Your router and the next device after it (local addresses) | Ping, and read their normal web page / status interface | No (this is the core of the check) |
| 8.8.8.8 (Google) and 1.1.1.1 (Cloudflare) | Pings and DNS lookups | No |
| Your current DNS servers | DNS speed comparison | No |
| `api.ipify.org` | See your public address, to detect shared addresses (CGNAT) | Yes: `-NoInternetServices` |
| `speed.cloudflare.com` | Speed test | Yes: `-NoSpeedTest` or `-NoInternetServices` |

Like any website you visit, those services see your public IP address when you
contact them.

## What ends up in the reports

Reports are saved only in the `reports/` folder on your computer (ignored by git,
so you won't accidentally publish them).

They **include**: your connection type, your router's local address and make/model,
test results, the masked first half of your public IP, your own Wi-Fi name.

They **leave out**: neighbours' Wi-Fi names (masked), MAC addresses, SIM numbers,
IMEI/IMSI, passwords and your full public IP.

`report.json` keeps a little more raw detail for AI agents (for example the
status fields your equipment returned without a login). Check it before sharing it.

## When you use an AI agent

Your agent (Claude, ChatGPT/Codex, Gemini, Grok, …) sees what Kebera prints and
the report files, and whatever it reads from your equipment pages after you sign
in. That data goes to the agent's provider under their privacy terms. Never paste
passwords into the chat; sign in to your router yourself.

Before sending a report to anyone, read it once and remove anything you aren't
comfortable sharing.
