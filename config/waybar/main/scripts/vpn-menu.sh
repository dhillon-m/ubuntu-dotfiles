#!/bin/bash
source ~/.cache/wal/colors.sh

CHOICE=$(printf "United Kingdom\nFrance\nGermany\nUnited States" | fuzzel --dmenu \
    --anchor=top-right --x-margin=5 --y-margin=5 --width=25 --minimal-lines \
    --font="Iosevka Nerd Font Propo:size=12" \
    --background="${background}ff" --text-color="${color3}ff" \
    --border-color="${color3}ff" --selection-color="${color3}ff" \
    --selection-text-color="${background}ff")

case "$CHOICE" in
    *"United Kingdom"*) protonvpn connect --country GB ;;
    *"France"*)         protonvpn connect --country FR ;;
    *"Germany"*)        protonvpn connect --country DE ;;
    *"United States"*)  protonvpn connect --country US ;;
esac
