# Working with your provider

Kebera is neutral: it measures, it does not take sides. Its value is that you can
show your provider **where** the problem is, instead of being told to restart the
router and wait for a call back.

## Before you contact them

1. Run Kebera (and ideally the long logger for a few hours, including an evening).
2. Fix anything Kebera found inside your home first (it's free and fast).
3. Have ready: your account or line number, your area, the report's verdict and
   a few key numbers. Kebera's `message-to-provider.txt` gives you a draft.

## What to ask for

| If Kebera found | Ask the provider to |
|---|---|
| Drops/lag beyond your equipment | Check the tower (cell) or line serving you for congestion or faults |
| Strong signal, poor quality (SINR/RSRQ) | Check the cell for congestion or interference; re-aim the outdoor unit |
| Weak signal | Re-aim or relocate the outdoor unit; confirm coverage |
| Slow speed with healthy signal | Confirm whether your line is limited (e.g. a fair-usage threshold on an "unlimited" bundle) |
| Outdoor unit reconnecting (timer resets) | Check the unit and the network side; replace the unit if faulty |
| Fibre Rx power below −27 dBm, or LOS light red | Send a technician to check the fibre and connectors |
| Strict NAT / need port forwarding | Provide a public IP address (may cost extra) |

Always ask for a **reference number**, and note the date, the time and the agent's name.

## Common responses, and how to answer

| They say | You can answer |
|---|---|
| "Restart your router." | "I have. My equipment tests healthy; the loss happens beyond it. Here are the results." |
| "Your signal is excellent." | "Signal *strength* is fine, but *quality* (SINR) is poor, which is what causes the lag." |
| "It's your Wi-Fi." | "My wired devices have the same problem, and pings to my router are clean." |
| "We'll call you back." | "Please give me a reference number and an expected time." |

## Providers

Mobile/5G home internet: Airtel Uganda, MTN Uganda, Lyca Mobile and others.
Fibre and fixed wireless: several companies, including Roke Telkom and other local ISPs.
Satellite: Starlink.

Most providers take complaints on WhatsApp, by phone, on social media and in
service centres. Use the official channels listed on your provider's website or SIM pack.

If a complaint isn't resolved in reasonable time, you can escalate to the
**Uganda Communications Commission (UCC)**. See `../templates/escalation-ucc.md`.

> Kebera is not affiliated with, endorsed by, or acting for any provider or
> manufacturer. Names are used only to identify equipment and services.
