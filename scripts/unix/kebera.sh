#!/usr/bin/env bash
# Kebera: read-only home internet check-up for macOS and Linux (beta).
#
# KEBERA IS NOT A HACKING TOOL. It only contacts your own router, the next
# private hop after it (found automatically) and fixed public test services.
# There is deliberately no option to choose other targets. Misuse or perversion
# of Kebera is not tolerated. See ACCEPTABLE_USE.md.
#
# Usage:  bash scripts/unix/kebera.sh [--quick] [--no-speedtest] [--no-internet-services] [--no-open]
#
# Runs ping, traceroute, DNS and speed tests, reads the normal web page of your
# router / outdoor unit (no login), and writes reports/<date>/report.md plus a
# ready-to-send message for your provider. Nothing on your network is changed.

set -u
VERSION="0.1.0"
QUICK=0; SPEED=1; NETSVC=1; OPEN=1
for a in "$@"; do
  case "$a" in
    --quick) QUICK=1 ;;
    --no-open) OPEN=0 ;;
    --no-speedtest) SPEED=0 ;;
    --no-internet-services) NETSVC=0; SPEED=0 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
  esac
done
COUNT=120; [ "$QUICK" = 1 ] && COUNT=40

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$ROOT/reports/$(date +%Y-%m-%d_%H%M)"
mkdir -p "$OUT"
OS="$(uname -s)"

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
note() { printf '    %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
is_private() {
  case "$1" in
    10.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[0-1].*) return 0 ;;
    100.6[4-9].*|100.[7-9][0-9].*|100.1[0-1][0-9].*|100.12[0-7].*) return 0 ;;
  esac
  return 1
}

echo "Kebera $VERSION - home internet check-up (read-only, beta for macOS/Linux)"
echo "Kebera is NOT a hacking tool. Use it only on your own connection. See ACCEPTABLE_USE.md."

# ---------------------------------------------------------------- connection
step "Checking how this computer is connected"
if [ "$OS" = "Darwin" ]; then
  GW="$(route -n get default 2>/dev/null | awk '/gateway/{print $2; exit}')"
  IFACE="$(route -n get default 2>/dev/null | awk '/interface/{print $2; exit}')"
  DNS="$(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/{print $3}' | sort -u | grep -E '^[0-9.]+$' | head -3 | tr '\n' ' ')"
else
  GW="$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')"
  IFACE="$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')"
  DNS="$(awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null | grep -E '^[0-9.]+$' | head -3 | tr '\n' ' ')"
  if echo "$DNS" | grep -q '127.0.0.53' && have resolvectl; then
    DNS="$(resolvectl dns 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u | head -3 | tr '\n' ' ')"
  fi
fi
[ -z "${GW:-}" ] && { echo "No active connection found. Connect and try again."; exit 1; }
note "Interface $IFACE, router $GW, DNS: ${DNS:-unknown}"

# ---------------------------------------------------------------- wi-fi
step "Checking Wi-Fi"
WIFI_SSID=""; WIFI_SIG=""; WIFI_CH=""; WIFI_NOISE=""; WIFI_BAND=""
if [ "$OS" = "Darwin" ]; then
  SP="$(system_profiler SPAirPortDataType 2>/dev/null)"
  CUR="$(echo "$SP" | awk '/Current Network Information:/{f=1;next} f&&/Other Local Wi-Fi Networks:/{exit} f')"
  WIFI_SSID="$(echo "$CUR" | awk 'NR==1{gsub(/^ +|:$/,"");print}')"
  WIFI_CH="$(echo "$CUR" | awk -F': ' '/Channel:/{print $2; exit}')"
  SN="$(echo "$CUR" | awk -F': ' '/Signal \/ Noise:/{print $2; exit}')"
  WIFI_SIG="$(echo "$SN" | grep -oE '^-?[0-9]+')"
  WIFI_NOISE="$(echo "$SN" | grep -oE '/ -?[0-9]+' | grep -oE '-?[0-9]+')"
  case "$WIFI_CH" in *5GHz*) WIFI_BAND="5 GHz";; *2GHz*) WIFI_BAND="2.4 GHz";; esac
  NEIGH="$(echo "$SP" | awk '/Other Local Wi-Fi Networks:/{f=1;next} f' | grep -c 'Channel:')"
  [ -n "$WIFI_SIG" ] && note "Signal $WIFI_SIG dBm, noise ${WIFI_NOISE:-?} dBm, channel $WIFI_CH; $NEIGH other networks visible"
elif have nmcli; then
  LINE="$(nmcli -t -f ACTIVE,SSID,CHAN,SIGNAL,FREQ dev wifi 2>/dev/null | grep '^yes' | head -1)"
  WIFI_SSID="$(echo "$LINE" | cut -d: -f2)"; WIFI_CH="$(echo "$LINE" | cut -d: -f3)"; WIFI_SIG="$(echo "$LINE" | cut -d: -f4)"
  [ -n "$WIFI_CH" ] && { if [ "$WIFI_CH" -gt 14 ] 2>/dev/null; then WIFI_BAND="5 GHz"; else WIFI_BAND="2.4 GHz"; fi; }
  NEIGH="$(nmcli -t -f SSID,CHAN,SIGNAL dev wifi 2>/dev/null | wc -l | tr -d ' ')"
  [ -n "$WIFI_SIG" ] && note "Wi-Fi signal $WIFI_SIG%, channel $WIFI_CH; $NEIGH networks visible"
  SAME_CH="$(nmcli -t -f SSID,CHAN,SIGNAL dev wifi 2>/dev/null | awk -F: -v c="$WIFI_CH" -v s="$WIFI_SSID" '$2==c && $1!=s && $3>=50' | wc -l | tr -d ' ')"
else
  note "Wi-Fi details not available (no nmcli). Continuing."
fi

# ---------------------------------------------------------------- route
step "Tracing the route to the internet"
UP=""
if have traceroute; then
  TR="$(traceroute -n -m 12 -w 1 -q 2 8.8.8.8 2>/dev/null)"
  H2="$(echo "$TR" | awk '$1=="2"{print $2; exit}')"
  if [ -n "$H2" ] && [ "$H2" != "*" ] && is_private "$H2" && [ "$H2" != "$GW" ]; then UP="$H2"; fi
  note "Next device after router: ${UP:-none detected}"
else
  TR="(traceroute not installed)"; note "traceroute not installed; skipping."
fi

# ---------------------------------------------------------------- devices
step "Identifying your equipment (reading pages they already show; no login)"
fingerprint() {
  local ip="$1" body vendor="" provider="" model=""
  body="$(curl -sk -m 5 -L "http://$ip/" 2>/dev/null)"
  [ -z "$body" ] && { echo "no web page"; return; }
  echo "$body" | grep -qiE '\bzte\b|logo_zte|goform' && vendor="ZTE"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'huawei|hilink|echolife' && vendor="Huawei"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'tp-?link' && vendor="TP-Link"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'mikrotik|routeros' && vendor="MikroTik"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'tenda' && vendor="Tenda"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'nokia' && vendor="Nokia"
  [ -z "$vendor" ] && echo "$body" | grep -qiE 'fiberhome' && vendor="FiberHome"
  echo "$body" | grep -qi 'airtel' && provider="Airtel"
  echo "$body" | grep -qiE '\bmtn\b' && provider="MTN"
  if [ "$vendor" = "ZTE" ]; then
    j="$(curl -sk -m 5 -e "http://$ip/index.html" "http://$ip/goform/goform_get_cmd_process?isTest=false&multi_data=1&cmd=model_name,cr_version" 2>/dev/null)"
    model="$(echo "$j" | grep -oE '"model_name":"[^"]*"' | cut -d'"' -f4)"
    echo "$j" | grep -qi airtel && provider="Airtel"
  fi
  echo "${vendor:-unknown make}${model:+ $model}${provider:+ ($provider)}"
}
GW_ID="$(fingerprint "$GW")"; note "$GW: $GW_ID"
UP_ID=""; [ -n "$UP" ] && { UP_ID="$(fingerprint "$UP")"; note "$UP: $UP_ID"; }

# ---------------------------------------------------------------- pings
pingstats() { # target count -> "loss avg max jitter"
  local out loss rtt
  if [ "$OS" = "Darwin" ]; then out="$(ping -c "$2" -i 0.5 -W 1500 "$1" 2>/dev/null)"; else out="$(ping -c "$2" -i 0.5 -W 2 "$1" 2>/dev/null)"; fi
  loss="$(echo "$out" | grep -oE '[0-9.]+% packet loss' | grep -oE '^[0-9.]+')"
  rtt="$(echo "$out" | grep -oE '= [0-9.]+/[0-9.]+/[0-9.]+/[0-9.]+' | tr -d '= ')"
  echo "${loss:-100} $(echo "$rtt" | cut -d/ -f2) $(echo "$rtt" | cut -d/ -f3) $(echo "$rtt" | cut -d/ -f4)"
}
step "Measuring stability ($COUNT pings to each point, run side by side)"
TMP="$(mktemp -d)"
pingstats "$GW" "$COUNT" > "$TMP/router" &
[ -n "$UP" ] && pingstats "$UP" "$COUNT" > "$TMP/up" &
pingstats 8.8.8.8 "$COUNT" > "$TMP/google" &
pingstats 1.1.1.1 "$COUNT" > "$TMP/cf" &
wait
read -r R_LOSS R_AVG R_MAX R_JIT < "$TMP/router"
U_LOSS=""; [ -f "$TMP/up" ] && read -r U_LOSS U_AVG U_MAX U_JIT < "$TMP/up"
read -r G_LOSS G_AVG G_MAX G_JIT < "$TMP/google"
read -r C_LOSS C_AVG C_MAX C_JIT < "$TMP/cf"
rm -rf "$TMP"
note "router     loss $R_LOSS%  avg ${R_AVG:-?} ms  worst ${R_MAX:-?} ms"
[ -n "$U_LOSS" ] && note "next dev   loss $U_LOSS%  avg ${U_AVG:-?} ms  worst ${U_MAX:-?} ms"
note "google     loss $G_LOSS%  avg ${G_AVG:-?} ms  worst ${G_MAX:-?} ms  jitter ${G_JIT:-?} ms"
note "cloudflare loss $C_LOSS%  avg ${C_AVG:-?} ms  worst ${C_MAX:-?} ms"

# ---------------------------------------------------------------- dns
step "Comparing DNS speed"
dnsavg() { # server -> avg ms
  have dig || { echo ""; return; }
  local t=0 n=0 q
  for d in google.com youtube.com facebook.com whatsapp.com microsoft.com netflix.com wikipedia.org cloudflare.com; do
    q="$(dig +tries=1 +time=2 @"$1" "$d" A 2>/dev/null | awk '/Query time:/{print $4}')"
    [ -n "$q" ] && { t=$((t+q)); n=$((n+1)); }
  done
  [ "$n" -gt 0 ] && echo $((t/n)) || echo ""
}
DNS_LINES=""
for s in $DNS 1.1.1.1 8.8.8.8; do
  a="$(dnsavg "$s")"; DNS_LINES="$DNS_LINES| $s | ${a:-n/a} ms |"$'\n'; note "$s: ${a:-n/a} ms"
done
have dig || note "Install 'dig' (dnsutils / bind-tools) for DNS timing."

# ---------------------------------------------------------------- speed & cgnat
DOWN=""; UPL=""; PUB=""
if [ "$NETSVC" = 1 ]; then
  PUB="$(curl -s -m 10 https://api.ipify.org 2>/dev/null)"
fi
if [ "$SPEED" = 1 ] && have curl; then
  DB=25000000; UB=5000000; [ "$QUICK" = 1 ] && { DB=10000000; UB=2000000; }
  step "Speed test (about $(( (DB+UB)/1000000 )) MB of data)"
  BPS="$(curl -s -m 120 -o /dev/null -w '%{speed_download}' "https://speed.cloudflare.com/__down?bytes=$DB" 2>/dev/null)"
  DOWN="$(awk -v b="$BPS" 'BEGIN{printf "%.1f", b*8/1000000}')"
  UBPS="$(head -c "$UB" /dev/zero | curl -s -m 120 -o /dev/null -w '%{speed_upload}' --data-binary @- https://speed.cloudflare.com/__up 2>/dev/null)"
  UPL="$(awk -v b="$UBPS" 'BEGIN{printf "%.1f", b*8/1000000}')"
  note "Download $DOWN Mbps, upload $UPL Mbps"
fi
CGNAT="unknown"
echo "$TR" | awk '$1>=2 && $1<=4 {print $2}' | while read -r ip; do is_private "$ip" && [ "$ip" != "$UP" ] && echo yes; done | grep -q yes && CGNAT="likely"

# ---------------------------------------------------------------- diagnosis
num() { awk -v x="${1:-0}" 'BEGIN{printf "%d", x+0.5}'; }
FIND=""; BAD_HOME=0; BAD_UP=0; BAD_PROV=0
add() { FIND="$FIND- **[$1] $2** $3"$'\n'; }
RL=$(num "$R_LOSS"); GL=$(num "$G_LOSS"); CL=$(num "$C_LOSS"); NL=$GL; [ "$CL" -lt "$NL" ] && NL=$CL
UL=0; [ -n "$U_LOSS" ] && UL=$(num "$U_LOSS")
if [ "$RL" -ge 3 ]; then
  if [ -n "$U_LOSS" ] && [ "$UL" -lt "$RL" ]; then add NOTE "Router ignores some pings" "($RL% to router, but only $UL% beyond it). Usually harmless."
  else add PROBLEM "Unreliable link to your router" "($RL% loss). Move closer, use 5 GHz, change Wi-Fi channel or check the cable."; BAD_HOME=1; fi
fi
if [ -n "$WIFI_SIG" ] && [ "$OS" != "Darwin" ] && [ "$WIFI_SIG" -lt 40 ] 2>/dev/null; then add PROBLEM "Weak Wi-Fi signal" "($WIFI_SIG%). Move closer to the router."; BAD_HOME=1; fi
if [ -n "$WIFI_SIG" ] && [ "$OS" = "Darwin" ] && [ "$WIFI_SIG" -lt -75 ] 2>/dev/null; then add PROBLEM "Weak Wi-Fi signal" "($WIFI_SIG dBm). Move closer to the router."; BAD_HOME=1; fi
if [ -n "$WIFI_NOISE" ] && [ -n "$WIFI_SIG" ] && [ $((WIFI_SIG - WIFI_NOISE)) -lt 20 ] 2>/dev/null; then add WATCH "Wi-Fi interference" "(signal-to-noise only $((WIFI_SIG - WIFI_NOISE)) dB; 25+ is healthy). Change channel or use 5 GHz."; fi
if [ "${SAME_CH:-0}" -ge 2 ] 2>/dev/null; then add WATCH "Neighbours share your Wi-Fi channel" "($SAME_CH strong networks on channel $WIFI_CH). Use 5 GHz or change channel."; fi
if [ -n "$U_LOSS" ] && [ $((UL - RL)) -ge 2 ]; then add PROBLEM "Drops between your router and the next device" "($UL% loss). Check the cable/power to your outdoor unit or modem."; BAD_UP=1; fi
PL=$((NL - (UL > RL ? UL : RL)))
if [ "$PL" -ge 2 ]; then add PROBLEM "Drops beyond your equipment" "(internet loss $NL% while your equipment lost under $((UL > RL ? UL : RL))%). Report to your provider."; BAD_PROV=1; fi
GA=$(num "$G_AVG"); GJ=$(num "$G_JIT")
[ "$GA" -gt 150 ] && add WATCH "High delay to the internet" "(average $GA ms; healthy is under 80 ms)."
if [ "$GJ" -gt 40 ]; then add PROBLEM "Very unstable delay (jitter $GJ ms)" "Typical of a congested network."; BAD_PROV=1; elif [ "$GJ" -gt 20 ]; then add WATCH "Unstable delay (jitter $GJ ms)" ""; fi
if [ -n "$DOWN" ]; then D=$(num "$DOWN"); if [ "$D" -lt 5 ]; then add PROBLEM "Very slow download ($DOWN Mbps)" "Ask the provider if your line is limited."; BAD_PROV=1; elif [ "$D" -lt 10 ]; then add WATCH "Slow download ($DOWN Mbps)" ""; else add OK "Download speed reasonable" "($DOWN Mbps down, $UPL Mbps up)."; fi; fi
[ "$CGNAT" = "likely" ] && add NOTE "Provider probably shares one public address (CGNAT)" "Consoles may show Strict NAT; ask for a public IP if you need one."

if [ $BAD_HOME = 1 ] && [ $((BAD_UP + BAD_PROV)) -gt 0 ]; then VERDICT="Problems were found both inside your home and beyond it. Fix the home items first."
elif [ $BAD_HOME = 1 ]; then VERDICT="The main problem is inside your home: your Wi-Fi or router."
elif [ $BAD_UP = 1 ] && [ $BAD_PROV = 0 ]; then VERDICT="The main problem is at your outdoor unit / modem or its cable."
elif [ $BAD_PROV = 1 ] || [ $BAD_UP = 1 ]; then VERDICT="The main problem is on your internet provider's side."
else VERDICT="No major problem showed up during this test. Run it again when the internet misbehaves."; fi

PROVIDER="$(echo "$GW_ID $UP_ID" | grep -oE 'Airtel|MTN' | head -1)"; PROVIDER="${PROVIDER:-[your provider]}"

# ---------------------------------------------------------------- reports
{
  echo "# Kebera internet check-up"; echo
  echo "Date: $(date '+%Y-%m-%d %H:%M') | Kebera $VERSION ($OS, beta)"; echo
  echo "## Verdict"; echo; echo "**$VERDICT**"; echo
  echo "## What we found"; echo; printf '%s' "${FIND:-- Nothing unusual.}"; echo
  echo "## Your setup"; echo
  echo "- Router $GW: $GW_ID"
  [ -n "$UP" ] && echo "- Next device $UP: $UP_ID"
  [ -n "$WIFI_SSID" ] && echo "- Wi-Fi: $WIFI_SSID, ${WIFI_BAND:-?}, channel $WIFI_CH, signal $WIFI_SIG"
  echo "- Shared public address (CGNAT): $CGNAT"; echo
  echo "## Stability ($COUNT pings each)"; echo
  echo "| Link | Lost | Average | Worst | Jitter |"; echo "|---|---|---|---|---|"
  echo "| Your router | $R_LOSS% | $R_AVG ms | $R_MAX ms | $R_JIT ms |"
  [ -n "$U_LOSS" ] && echo "| Next device | $U_LOSS% | $U_AVG ms | $U_MAX ms | $U_JIT ms |"
  echo "| Google 8.8.8.8 | $G_LOSS% | $G_AVG ms | $G_MAX ms | $G_JIT ms |"
  echo "| Cloudflare 1.1.1.1 | $C_LOSS% | $C_AVG ms | $C_MAX ms | $C_JIT ms |"; echo
  [ -n "$DOWN" ] && { echo "## Speed"; echo; echo "Download $DOWN Mbps, upload $UPL Mbps."; echo; }
  echo "## DNS speed"; echo; echo "| Server | Average |"; echo "|---|---|"; printf '%s' "$DNS_LINES"; echo
  echo "## Route"; echo; echo '```'; echo "$TR"; echo '```'; echo
  echo "---"; echo "Generated by Kebera (read-only, open source). Ping-based tests run side by side but not perfectly in step on macOS/Linux; the Windows version compares every moment exactly."; echo; echo "Kebera is community-built. Network, telecom and fibre engineers, technicians and translators: help make it better at https://github.com/kazibwefrancis/Kebera"
} > "$OUT/report.md"

{
  echo "Hello $PROVIDER team,"; echo
  echo "My home internet (account/line: [your number]) has been [slow / dropping]. I ran a check-up on $(date '+%Y-%m-%d %H:%M'):"; echo
  echo "- My router: $R_LOSS% loss, average $R_AVG ms"
  [ -n "$U_LOSS" ] && echo "- Next device (outdoor unit / modem): $U_LOSS% loss, average $U_AVG ms"
  echo "- Internet (Google/Cloudflare): $NL% loss, average $G_AVG ms, worst $G_MAX ms, jitter $G_JIT ms"
  [ -n "$DOWN" ] && echo "- Speed: $DOWN Mbps down, $UPL Mbps up"
  echo; echo "Conclusion: $VERDICT"; echo
  echo "Please check the network serving my area, tell me whether my line is being limited for any reason, and send me a reference number."
  echo; echo "Thank you,"; echo "[Your name]"; echo "[Area / location]"
} > "$OUT/message-to-provider.txt"

printf '\n\033[33mVERDICT: %s\033[0m\n' "$VERDICT"
echo "Reports saved in: $OUT"
echo "  report.md                - the full report"
echo "  message-to-provider.txt  - ready-to-send complaint draft"
echo "Open them with any text editor (on a Mac: right-click > Open With > TextEdit)."

# Show the report folder (Finder on macOS, the file manager on Linux desktops).
if [ "$OPEN" = 1 ]; then
  if [ "$OS" = "Darwin" ]; then
    open "$OUT" 2>/dev/null
  elif have xdg-open && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    xdg-open "$OUT" >/dev/null 2>&1 &
  fi
fi
