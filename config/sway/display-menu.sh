#!/bin/bash
# Display-switch menu for the laptop's Fn+F8 (XF86Display) key — the Sway
# equivalent of Windows' Win+P: laptop only / extend / mirror / external only.
source ~/.cache/wal/colors.sh

INTERNAL=$(swaymsg -t get_outputs | jq -r '.[].name | select(test("^(eDP|LVDS)"))' | head -1)
EXTERNAL=$(swaymsg -t get_outputs | jq -r '.[].name | select(test("^(eDP|LVDS)") | not)')

notify() { command -v notify-send >/dev/null && notify-send "Display" "$1"; }

if [[ -z "$EXTERNAL" ]]; then
    notify "No external display connected"
    exit 0
fi

CHOICE=$(printf "󰌢  Laptop only
󰍺  Extend
󰍹  Mirror
󰶐  External only" | \
    fuzzel --dmenu \
    --width=20 \
    --minimal-lines \
    --font="Iosevka Nerd Font Propo:size=12" \
    --background="${background}ff" \
    --text-color="${color4}ff" \
    --border-color="${color4}ff" \
    --selection-color="${color4}ff" \
    --selection-text-color="${background}ff")

[[ -z "$CHOICE" ]] && exit 0
pkill -x wl-mirror

case "$CHOICE" in
    *"Laptop only")
        swaymsg output "$INTERNAL" enable
        for o in $EXTERNAL; do swaymsg output "$o" disable; done ;;
    *"Extend")
        swaymsg output "$INTERNAL" enable
        for o in $EXTERNAL; do swaymsg output "$o" enable; done ;;
    *"Mirror")
        if ! command -v wl-mirror >/dev/null; then
            notify "Mirroring needs wl-mirror (sudo apt install wl-mirror)"
            exit 1
        fi
        swaymsg output "$INTERNAL" enable
        for o in $EXTERNAL; do
            swaymsg output "$o" enable
            wl-mirror --fullscreen-output "$o" "$INTERNAL" &
        done ;;
    *"External only")
        for o in $EXTERNAL; do swaymsg output "$o" enable; done
        swaymsg output "$INTERNAL" disable ;;
esac
