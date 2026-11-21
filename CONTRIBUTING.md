# Contributing to Kebera

Thank you for helping. Kebera exists so people don't have to be at the mercy of
"restart your router". Every contribution makes the next diagnosis better.

## Ways to help

1. **Device reports (most valuable).** Ran Kebera on equipment it didn't
   recognise, or found the signal page somewhere else? Open an issue with the
   **Device report** template. Remove SIM numbers, IMEI/IMSI, serial numbers,
   MAC addresses, passwords and public IPs first.
2. **Real-world cases.** A short anonymised write-up like
   `examples/case-study-kampala-5g.md` helps others recognise their own problem.
3. **Translations.** Report text and guides in Luganda, Swahili, Runyankole,
   Acholi, Lusoga and other languages.
4. **Testing on macOS and Linux.** The Unix script is beta.
5. **Non-English Windows.** Add `netsh` output parsing for other display languages.
6. **Code.** Bug fixes, better rules, new device probes.

## Rules for code contributions

Kebera must stay safe and trustworthy:

- **Read-only.** No code that changes device or computer settings.
- **No authentication bypass.** Only requests a device's own web page makes before
  login. No default-password lists, brute forcing, exploits or "hidden" admin
  endpoints.
- **No identifiers in output.** Strip IMEI/IMSI/ICCID, serial numbers, MAC
  addresses, phone numbers and full public IPs before anything is written to a report.
- **Neutral wording.** Describe measurements, not blame.
- **Windows PowerShell 5.1 compatible**, ASCII-only `.ps1` files (PowerShell 5.1
  misreads non-ASCII characters in files without a BOM). No external modules.
- **Plain language** in anything a user reads.

## Adding a device probe

`Get-DeviceFingerprint` in `scripts/windows/kebera.ps1`:

1. Add a page pattern to `$VendorPatterns` (or `$ProviderPatterns` / `$RolePatterns`).
2. If the make has a status interface its web page calls **before login**, add an
   `Invoke-<Make>Probe` function modelled on `Invoke-ZteProbe`, filtering out
   identifiers.
3. Document where the useful readings live in `docs/devices/<make>.md`.
4. Add the model to the "Tested so far" table in `docs/devices/README.md`.

## Pull requests

**Only the maintainer merges changes into this repository.** Anyone can fork
Kebera and open a pull request; the maintainer reviews it and decides whether it
is accepted. Pull requests that weaken Kebera's safeguards, or add anything
covered by "Not allowed" in [ACCEPTABLE_USE.md](ACCEPTABLE_USE.md), will be closed.

- One topic per pull request, with a short description of what you tested and on
  which equipment.
- Run `kebera.ps1 -Quick -NoSpeedTest` before submitting script changes.
- Be kind. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
