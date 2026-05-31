#!/bin/bash
STATE=$(nmcli radio wifi)
if [[ "$STATE" == "enabled" ]]; then nmcli radio wifi off
else                                  nmcli radio wifi on
fi
