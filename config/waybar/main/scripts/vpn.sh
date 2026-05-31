#!/bin/bash
source ~/.cache/wal/colors.sh

STATUS=$(protonvpn status 2>/dev/null)
CONNECTED=$(echo "$STATUS" | grep "^Status:" | awk '{print $2}')

if [[ "$CONNECTED" == "Connected" ]]; then
    COUNTRY=$(echo "$STATUS" | grep "^Server:" | awk '{print $2}' | grep -oP '^[A-Z]+')
    printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$color3'> 󰦝 </span> $COUNTRY\",\"class\":\"connected\"}"
else
    printf "%s\n" "{\"text\":\"<span color='$background' bgcolor='$color3'> 󰦞 </span> OFF\",\"class\":\"disconnected\"}"
fi
