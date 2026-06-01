#!/bin/bash
source ~/.cache/wal/colors.sh

CHOICE=$(printf "⏻  Shutdown
  Restart
󰒲  Sleep
  Lock
  Log Out" | \
    fuzzel --dmenu \
    --width=20 \
    --minimal-lines \
    --font="Iosevka Nerd Font Propo:size=12" \
    --background="${background}ff" \
    --text-color="${color1}ff" \
    --border-color="${color1}ff" \
    --selection-color="${color1}ff" \
    --selection-text-color="${background}ff")

case "$CHOICE" in
    "⏻  Shutdown")  systemctl poweroff ;;
    "  Restart")   systemctl reboot ;;
    "󰒲  Sleep")     systemctl suspend ;;
    "  Lock")      gtklock ;;
    "  Log Out")   swaymsg exit ;;
esac
