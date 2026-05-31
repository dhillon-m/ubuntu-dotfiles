#!/usr/bin/env bash
source ~/.cache/wal/colors.sh

find_hwmon() {
    for d in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$d/name" 2>/dev/null)" == "$1" ]] && echo "$d" && return
    done
}

CPU_DIR=$(find_hwmon "k10temp")
if [[ -z "$CPU_DIR" ]]; then
    printf "%s\n" "{\"text\":\"<span color='$foreground' bgcolor='$color8' >  </span> N/A\",\"class\":\"unknown\"}"
    exit 0
fi

TEMP=$(( $(cat "$CPU_DIR/temp1_input") / 1000 ))

read -ra s1 < <(grep '^cpu ' /proc/stat)
sleep 0.2
read -ra s2 < <(grep '^cpu ' /proc/stat)
idle1=$(( s1[4] + s1[5] )); idle2=$(( s2[4] + s2[5] ))
total1=0; for v in "${s1[@]:1}"; do (( total1 += v )); done
total2=0; for v in "${s2[@]:1}"; do (( total2 += v )); done
dtotal=$(( total2 - total1 )); didle=$(( idle2 - idle1 ))
(( dtotal > 0 )) && UTIL=$(( (dtotal - didle) * 100 / dtotal )) || UTIL=0

if (( TEMP >= 70 )); then
    CLASS="critical"
    FORMAT="<span color='$background' bgcolor='$color1' >  </span> $UTIL%  $TEMP°C"
else
    CLASS="normal"
    FORMAT="<span color='$background' bgcolor='$color2' >  </span> $UTIL%  $TEMP°C"
fi

printf "%s\n" "{\"text\":\"$FORMAT\",\"class\":\"$CLASS\"}"
