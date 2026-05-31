#!/usr/bin/env bash
source ~/.cache/wal/colors.sh

# Set to your discrete GPU's PCI address.
# Run: lspci | grep -i vga   →  e.g. "03:00.0 VGA … Radeon RX 6700"
# Then set: DISCRETE_PCI="0000:03:00.0"
DISCRETE_PCI="0000:03:00.0"

GPU_DIR=""
for d in /sys/class/hwmon/hwmon*; do
    [[ "$(cat "$d/name" 2>/dev/null)" != "amdgpu" ]] && continue
    dev_path=$(realpath "$d/device" 2>/dev/null)
    if [[ "$dev_path" == *"$DISCRETE_PCI"* ]]; then
        GPU_DIR="$d"
        break
    fi
done

if [[ -z "$GPU_DIR" ]]; then
    printf "%s\n" "{\"text\":\"<span color='$foreground' bgcolor='$color8' > 󰢮 </span> N/A\",\"class\":\"unknown\"}"
    exit 0
fi

TEMP=$(( $(cat "$GPU_DIR/temp1_input") / 1000 ))
UTIL=$(cat "$GPU_DIR/device/gpu_busy_percent" 2>/dev/null || echo 0)

if (( TEMP >= 70 )); then
    FORMAT="<span color='$background' bgcolor='$color1' >  </span> $UTIL%  $TEMP°C"
    CLASS="critical"
else
    FORMAT="<span color='$background' bgcolor='$color3' > 󰢮 </span> $UTIL%  $TEMP°C"
    CLASS="normal"
fi

printf "%s\n" "{\"text\":\"$FORMAT\",\"class\":\"$CLASS\"}"
