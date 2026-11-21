# Fibre modems (ONTs)

With fibre to the home, a small box (the **ONT**, sometimes called the fibre
modem or "terminal") turns the light in the fibre into a network connection.
Common makes: Huawei (EchoLife HG/EG series), ZTE (F-series), Nokia (G-series),
FiberHome (AN/HG series). Some include Wi-Fi; others connect to a separate router.

## Lights to check first (no computer needed)

| Light | Normal | Problem |
|---|---|---|
| Power | On | Off: check power adapter |
| PON | Steady | Flashing for a long time: the ONT can't register with the provider |
| LOS | **Off** | **Red / flashing: no light from the fibre** (cut, unplugged, badly bent) |
| LAN | On/flashing for connected cables | Off: cable or port problem |

A red LOS light is always the provider's job to fix (or a fibre cable you can see
is bent or pinched: straighten it gently; never look into the fibre).

## The key number: optical receive power

On the ONT's status page (often **Status > Optical Information**, **PON Information**
or **WAN > Optical**):

| Rx power | Meaning |
|---|---|
| −8 to −25 dBm | Healthy |
| −25 to −27 dBm | Weak; can cause drops when combined with dirt or bends |
| below −27 dBm | Faulty line or connector: report it with this reading |

Also useful: **Tx power** (usually +0.5 to +5 dBm), ONT **uptime**, and the
**PON/registration state** ("O5" or "Operation" means fully registered on many models).

## How Kebera sees fibre

- If the ONT is also your Wi-Fi router, it is "Your router".
- If you have a separate router, the ONT is often "the next device".
- Many ONTs only allow viewing after login; ask the provider for the user login if
  you don't have one (the "admin" login is often kept by the provider).

## Typical fibre problems

| Symptom | Likely cause |
|---|---|
| LOS red, no internet | Fibre cut or unplugged (provider) |
| Works, then drops at random | Weak Rx power, dirty connector, damaged patch cord |
| Everything up, but slow in evenings | Provider network congestion |
| Fast wired, slow Wi-Fi | Wi-Fi problem in the home, not the fibre |
