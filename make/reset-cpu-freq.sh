#!/usr/bin/env bash
# reset-cpu-freq.sh — restore CPU frequency settings to normal (Fedora/Ryzen)
# Usage: sudo ./reset-cpu-freq.sh

# 1. Restore governor to 'performance' (Fedora default)
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  if [ -f "$c/cpufreq/scaling_governor" ]; then
    echo performance | sudo tee "$c/cpufreq/scaling_governor" >/dev/null
  fi
done
echo "→ Governor set to performance."

# 2. Reset min/max frequency to full range
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  if [ -f "$c/cpufreq/scaling_min_freq" ] && [ -f "$c/cpufreq/scaling_max_freq" ]; then
    min=$(cat "$c/cpufreq/cpuinfo_min_freq")
    max=$(cat "$c/cpufreq/cpuinfo_max_freq")
    echo $min | sudo tee "$c/cpufreq/scaling_min_freq" >/dev/null
    echo $max | sudo tee "$c/cpufreq/scaling_max_freq" >/dev/null
  fi
done
echo "→ Frequency range restored to hardware limits."

# 3. Show summary
echo
echo "Current settings summary:"
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  cur=$(cat "$c/cpufreq/scaling_cur_freq" 2>/dev/null || echo N/A)
  gov=$(cat "$c/cpufreq/scaling_governor" 2>/dev/null || echo N/A)
  printf "%4s: %8s MHz  (%s)\n" "$(basename $c)" "$((cur/1000))" "$gov"
done

echo
echo "✅ CPU frequency control reset to normal dynamic behavior."
