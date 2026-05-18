#!/usr/bin/env bash
# set-cpu-freq.sh — set all CPUs to a fixed frequency
# Usage: sudo ./set-cpu-freq.sh <freq_mhz>
# Example: sudo ./set-cpu-freq.sh 2300   # match perf-lab Xeon 5218

if [ -z "$1" ]; then
  echo "Usage: $0 <freq_mhz>"
  echo "  e.g. $0 2300  (2.3 GHz, matches perf-lab Xeon Gold 5218)"
  echo "  e.g. $0 4300  (4.3 GHz, Ryzen 9 7950X base)"
  exit 1
fi

FREQ_MHZ=$1
BASE_FREQ=$((FREQ_MHZ * 1000))  # convert to kHz

# Validate against hardware limits
HW_MIN=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq)
HW_MAX=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)

if [ "$BASE_FREQ" -lt "$HW_MIN" ] || [ "$BASE_FREQ" -gt "$HW_MAX" ]; then
  echo "Error: ${FREQ_MHZ} MHz is outside hardware range [$(($HW_MIN/1000))-$(($HW_MAX/1000))] MHz"
  exit 1
fi

echo "Setting all CPUs to fixed ${FREQ_MHZ} MHz..."

echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost > /dev/null
echo "  Boost disabled"

for c in /sys/devices/system/cpu/cpu[0-9]*; do
  echo performance | sudo tee $c/cpufreq/scaling_governor > /dev/null
  echo $BASE_FREQ | sudo tee $c/cpufreq/scaling_min_freq > /dev/null
  echo $BASE_FREQ | sudo tee $c/cpufreq/scaling_max_freq > /dev/null
done
echo "  Governor: performance, freq: ${FREQ_MHZ} MHz"

echo ""
echo "Verifying:"
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  cur=$(cat $c/cpufreq/scaling_cur_freq)
  echo "  $(basename $c): $(($cur/1000)) MHz"
done
