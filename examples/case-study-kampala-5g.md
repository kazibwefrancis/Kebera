# Case study: "Everything is slow, it must be the router"

A real diagnosis from November 2026 that led to Kebera. Identifiers removed.

## The complaint

> "My Xbox, my laptop, my phone: sometimes the internet just gives up, or it's
> there but it's not doing what I want. It started with the router. All my
> devices were working fine before."

## The setup (found by the checks)

```
Phone (5 GHz) ┐
Laptop (Wi-Fi)┼~~Wi-Fi~~ [Indoor router: ZTE MF296A] ──cable── [5G outdoor unit: ZTE G5FA] ~~5G/4G~~ Airtel tower
TV (2.4 GHz)  ┘                   │
Xbox Series X/S ────cable─────────┘
```

## What was checked

| Check | Result | Verdict |
|---|---|---|
| Xbox to router (100 pings) | 0% loss, ~2 ms | Home network healthy |
| Router to outdoor unit, incl. 1,472-byte and 8,000-byte packets | 0 lost of 350 | Cable and unit healthy |
| Outdoor unit diagnosis page | SIM ready, registered, connected | Healthy |
| 5G signal (n78, 100 MHz) | RSRP −59 dBm, SINR 12.5–14.5 dB | Strong and clean |
| 4G anchor (Band 7, 20 MHz) | RSRP −66 dBm, SINR 6–8 dB, RSRQ −11 to −14 dB | Strong but **noisy** |
| 4G second carrier (Band 1, 15 MHz) | SINR 0–9 dB, swinging | **Poor** |
| RSSI-vs-RSRP interference check | Band 7: expected −35 dBm, measured −37 to −39 dBm | **No external interference**: busy cell |
| Internet beyond the outdoor unit | Loss and spikes up to 1.4 s while home links were clean | **Provider side** |
| Outdoor unit connection timer | Had reset that morning | Link to provider dropped |
| Data used this month | ~430 GB | Possible fair-usage limits |
| Wi-Fi neighbourhood | 3 strong neighbours on the laptop's 2.4 GHz channel 11 | Minor, local |
| DNS: router vs public | 232 ms vs ~157 ms average | Public DNS faster |
| NAT type on Xbox | Strict | Provider uses shared addresses (CGNAT) |

## Verdict

**Equipment healthy. The drops and lag were on the provider's side**: a congested
4G anchor cell (5G in NSA mode depends on it), possibly combined with fair-usage
deprioritisation. No sign of jamming.

## What the person did

1. Split the router's Wi-Fi into separate 2.4 GHz and 5 GHz names (Single SSID
   off). Laptop and phone moved to 5 GHz: laptop-to-router delay fell from up to
   58 ms to about 2 ms. The TV stayed on 2.4 GHz.
2. Set the Xbox DNS to 1.1.1.1 / 8.8.8.8 for faster sign-in and matchmaking.
3. Sent the provider a short WhatsApp complaint with the evidence, asking for a
   cell check, fair-usage status and a reference number.

## Lessons that shaped Kebera

- Ping **every link at the same moment**; the first failing link is the answer.
- Use **two** internet targets, so one busy server can't create false alarms.
- Read the **equipment's own status pages**; that's where signal quality, uptime
  and data usage live.
- "Strong signal" isn't "good signal": check SINR/RSRQ, and use the RSSI check
  before suspecting interference.
- People need a **ready-to-send message**, not just numbers.
