#!/bin/bash
source ~/.cache/wal/colors.sh

nmcli device wifi rescan 2>/dev/null
sleep 1

NETWORKS=$(nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | \
    grep -v "^:" | sort -t: -k2 -rn | \
    awk -F: '{printf "%s (%s%%)\n", $1, $2}' | head -20)

CHOICE=$(echo "$NETWORKS" | fuzzel --dmenu \
    --anchor=top-right --x-margin=5 --y-margin=5 --width=35 --minimal-lines \
    --font="Iosevka Nerd Font Propo:size=12" \
    --background="${background}ff" --text-color="${color5}ff" \
    --border-color="${color5}ff" --selection-color="${color5}ff" \
    --selection-text-color="${background}ff" --prompt="󰤨  WiFi: ")

[[ -z "$CHOICE" ]] && exit 0

SSID=$(echo "$CHOICE" | sed 's/ ([0-9]*%)$//')
SAVED=$(nmcli connection show | grep "$SSID")

if [[ -n "$SAVED" ]]; then
    nmcli connection up "$SSID"
else
    PASSWORD=$(echo "" | fuzzel --dmenu \
        --anchor=top-right --x-margin=5 --y-margin=5 --width=35 --minimal-lines \
        --font="Iosevka Nerd Font Propo:size=12" \
        --background="${background}ff" --text-color="${color5}ff" \
        --border-color="${color5}ff" --selection-color="${color5}ff" \
        --selection-text-color="${background}ff" --prompt="󰌆  Password: ")
    [[ -z "$PASSWORD" ]] && exit 0
    nmcli device wifi connect "$SSID" password "$PASSWORD"
fi
