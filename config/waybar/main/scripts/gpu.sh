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

if [[ -n "$GPU_DIR" ]]; then
    # ── AMD discrete GPU ──────────────────────────────────────────────────────
    TEMP=$(( $(cat "$GPU_DIR/temp1_input") / 1000 ))
    UTIL=$(cat "$GPU_DIR/device/gpu_busy_percent" 2>/dev/null || echo 0)
else
    # ── Intel integrated GPU (no amdgpu hwmon) ────────────────────────────────
    # Utilisation: sample RC6 residency (idle/power-save state) over 500 ms.
    # RC6 is cumulative ms the GPU spent idle; delta vs wall time = idle %.
    GT="/sys/class/drm/card1/gt/gt0"
    if [[ ! -f "$GT/rc6_residency_ms" ]]; then
        printf "%s\n" "{\"text\":\"<span color='$foreground' bgcolor='$color8' > 󰢮 </span> N/A\",\"class\":\"unknown\"}"
        exit 0
    fi
    rc6_1=$(cat "$GT/rc6_residency_ms")
    sleep 0.5
    rc6_2=$(cat "$GT/rc6_residency_ms")
    delta_rc6=$(( rc6_2 - rc6_1 ))
    # Active time = 500ms window minus time spent idle in RC6
    active=$(( 500 - delta_rc6 ))
    (( active < 0 )) && active=0
    UTIL=$(( active * 100 / 500 ))
    # Temperature: Intel iGPU shares the CPU die — use coretemp package sensor
    for d in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$d/name" 2>/dev/null)" == "coretemp" ]] && CORE_DIR="$d" && break
    done
    TEMP=$(( $(cat "${CORE_DIR:-/sys/class/hwmon/hwmon7}/temp1_input") / 1000 ))
fi

if (( TEMP >= 70 )); then
    FORMAT="<span color='$background' bgcolor='$color1' > 󰢮 </span> $UTIL%  $TEMP°C"
    CLASS="critical"
else
    FORMAT="<span color='$background' bgcolor='$color3' > 󰢮 </span> $UTIL%  $TEMP°C"
    CLASS="normal"
fi

printf "%s\n" "{\"text\":\"$FORMAT\",\"class\":\"$CLASS\"}"
