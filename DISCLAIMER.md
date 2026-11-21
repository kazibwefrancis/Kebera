# Disclaimer

**Please read before using Kebera.**

## Kebera is a diagnostic tool, not a hacking tool

- Kebera is **read-only**. It runs standard network tests (ping, traceroute, DNS
  lookups, an optional speed test) and opens the normal web pages that home
  routers, outdoor units and fibre modems already show, the same requests your
  browser sends when you type the router's address.
- Kebera **does not** log in to devices, guess or try default passwords, bypass
  authentication, exploit vulnerabilities, change settings, modify firmware,
  intercept other people's traffic or scan other people's networks.
- Listing nearby Wi-Fi networks uses the same information every phone and laptop
  receives. Kebera hides neighbours' network names in its reports.
- The AI-agent instructions (`AGENTS.md`) tell agents to follow the same rules:
  no password handling, no login bypass, no changes without the user's explicit
  consent.

## Use it only on networks you are allowed to test

Run Kebera only on your own connection or one you have permission to diagnose.
You are responsible for how you use it. **Misuse or perversion of Kebera is not
tolerated.** Using it, or a modified version, against networks or devices you
don't own or aren't permitted to test may be a crime, and is entirely the
user's responsibility. See [ACCEPTABLE_USE.md](ACCEPTABLE_USE.md).

## Not affiliated with any provider or manufacturer

Kebera is an independent open-source project. It is **not affiliated with,
endorsed by or acting for** Airtel, MTN, Lyca, Roke Telkom, Starlink, the Uganda
Communications Commission, ZTE, Huawei, TP-Link, Nokia, FiberHome, Ubiquiti,
Cambium, MikroTik or any other company or organisation mentioned. All trademarks
belong to their owners and are used only to identify equipment and services.

## Results are indicative, not guaranteed

Network conditions change from minute to minute. A Kebera report describes what
was measured during the test, using rules of thumb that can be wrong in unusual
setups. It is not a certified measurement, legal evidence of a contract breach or
professional advice. Use it as a well-informed starting point for a conversation
with your provider.

## Data usage

The optional speed test downloads and uploads about 30 MB (about 12 MB in quick
mode). Skip it with `-NoSpeedTest` / `--no-speedtest` on metered connections.

## No warranty

Kebera is provided "as is", without warranty of any kind. See [LICENSE](LICENSE).
