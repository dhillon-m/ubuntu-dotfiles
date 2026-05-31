#!/bin/bash
source ~/.cache/wal/colors.sh

IFACE=$(ip route show default | awk '{print $5}' | head -1)

if [[ -z "$IFACE" ]]; then
    printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$color5'> 󰤭 </span> OFF\",\"class\":\"disconnected\"}"
    exit 0
fi

RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
sleep 1
RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
BPS=$(( (RX2 - RX1) * 8 ))

if (( BPS >= 1000000 )); then   RATE="$(( BPS / 1000000 ))Mb/s"
elif (( BPS >= 1000 )); then    RATE="$(( BPS / 1000 ))Kb/s"
else                             RATE="${BPS}b/s"
fi

[[ "$IFACE" == wl* ]] && ICON="󰤨" || ICON="󰈀"

printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$color5'> $ICON </span> $RATE\",\"class\":\"connected\"}"
