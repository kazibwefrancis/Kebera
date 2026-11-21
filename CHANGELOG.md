# Changelog

## 0.1.0 (2026-11-21)

First release.

- Windows check-up (`kebera.ps1`): connection, Wi-Fi and neighbourhood scan
  (with fresh scan), route, equipment identification (ZTE and Huawei status
  interfaces, page fingerprints for other makes), simultaneous multi-link
  stability test, DNS comparison, CGNAT detection, optional speed test,
  mobile-signal grading, plain-language verdict.
- Reports: HTML, Markdown, JSON and a ready-to-send provider message, with
  identifiers removed.
- Long logger (`kebera-log.ps1`) and analyser (`kebera-analyze-log.ps1`):
  outages, where each failure happened, hour-by-hour view.
- Double-click launcher (`kebera.bat`).
- macOS/Linux check-up (`kebera.sh`, beta).
- `AGENTS.md` playbook for AI coding agents.
- Guides: interpreting results, connection types, interference and jamming,
  ZTE/Huawei/fibre/other devices, working with providers, message templates.
