#!/usr/bin/env bash
source ~/.cache/wal/colors.sh

BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep -iE '^BAT' | head -1)
if [[ -z "$BAT" ]]; then
    printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$color2' letter_spacing='2048'> 󰂄 </span> 100%\",\"class\":\"full\"}"
    exit 0
fi

CAPACITY=$(cat /sys/class/power_supply/$BAT/capacity 2>/dev/null || echo 0)
STATUS=$(cat /sys/class/power_supply/$BAT/status 2>/dev/null || echo "Unknown")
ICONS=("󰂎" "󰁺" "󰁻" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
IDX=$(( CAPACITY * 9 / 100 ))
ICON=${ICONS[$IDX]}

if [[ "$STATUS" == "Charging" ]]; then
    if (( CAPACITY <= 20 )); then CLASS="charging-critical"; BG="$color1"; ICON="󰢜"
    elif (( CAPACITY <= 30 )); then CLASS="charging-warning";  BG="$color6"; ICON="󰢝"
    else                             CLASS="charging";          BG="$color2"; ICON="󰂅"
    fi
elif [[ "$STATUS" == "Full" ]] || (( CAPACITY >= 99 )); then
    CLASS="full"; BG="$color2"
elif (( CAPACITY <= 20 )); then CLASS="critical"; BG="$color1"
elif (( CAPACITY <= 30 )); then CLASS="warning";  BG="$color6"
else                             CLASS="good";     BG="$color3"
fi

printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$BG' > $ICON </span> $CAPACITY%\",\"class\":\"$CLASS\"}"
