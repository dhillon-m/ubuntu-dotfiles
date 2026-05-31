#!/bin/bash
STATUS=$(protonvpn status 2>/dev/null | grep "^Status:" | awk '{print $2}')
if [[ "$STATUS" == "Connected" ]]; then protonvpn disconnect
else                                     protonvpn connect
fi
