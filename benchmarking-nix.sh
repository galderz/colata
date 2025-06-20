#!/usr/bin/env bash

set -e

source .env

DRY_RUN=true

if [[ -z "${NETWORK_INTERFACE}" ]]; then
  NETWORK_IF="eth0"
else
  NETWORK_IF="${NETWORK_INTERFACE}"
fi

# Check for dry-run parameter
if [[ "$1" == "--dry-run=false" ]]; then
    read -p "Are you sure you want to make the changes? (yes/no): " RESPONSE
    if [[ "$RESPONSE" == "yes" ]]; then
        DRY_RUN=false
    else
        echo "Exiting because you don't want to apply the changes."
        exit 1
    fi
fi

disable_hyperthreading() {
    # Run the lscpu command and parse its output to get the value for "Thread(s) per core"
    local threads_per_core=$(lscpu | grep "Thread(s) per core:" | awk '{print $NF}')

    # Check if the value is 1
    if [ "$threads_per_core" == "1" ]; then
        echo "SUCCESS: Thread(s) per core is 1. Nothing to do."
    else
        echo "ERROR: Thread(s) per core is not 1. It's $threads_per_core."
        if [[ $dry_run == "true" ]]; then
           echo "Dry-run mode: Hyper-threading would be disabled if not in dry-run mode."
        else
            echo "Run mode: disabled hyper threading in BIOS."
        fi
    fi
}

disable_turbo() {
    local no_turbo=$(cat "/sys/devices/system/cpu/intel_pstate/no_turbo")
    local desired_value="1"

    # Check if the value is 1
    if [ "$no_turbo" == "$desired_value" ]; then
        echo "SUCCESS: No turbo boost is 1. Nothing to do."
    else
        echo "ERROR: No turbo boost is not 1. It's $no_turbo."
        if [[ $dry_run == "true" ]]; then
            echo "Dry-run mode: No turbo boost would be enabled if not in dry-run mode."
        else
            echo "Run mode: No turbo boost to $desired_value value..."
            echo "$desired_value" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null
        fi
    fi
}

performance_scaling_governor() {
    local dry_run=$1
    local cpu_path="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
    local current_value=$(cat "$cpu_path")
    # Default value is schedutil
    local desired_value="performance"

    # Compare the current governor with the desired one
    if [[ "$current_value" != "$desired_value" ]]; then
        echo "ERROR: CPU mode is not $desired_value."
        if [[ $dry_run == "true" ]]; then
           echo "Dry-run mode: CPU would be set to $desired_value mode if not in dry-run mode."
        else
            # Set the governor to "performance"
            echo "Run mode: Setting CPU to $desired_value mode..."
            echo "$desired_value" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
        fi
    else
        echo "SUCCESS: CPU is already in $desired_value mode."
    fi
}

perf_event_paranoid() {
    local dry_run=$1
    local current_value=$(sysctl -n kernel.perf_event_paranoid)
    local desired_value=1

    if [ "$current_value" != "$desired_value" ]; then
        echo "ERROR: Perf event paranoid is not $desired_value."
        if [[ $dry_run == "true" ]]; then
            echo "Dry-run mode: Perf event paranoid would be set $desired_value if not in dry-run mode."
        else
            echo "Run mode: Setting perf event paranoid to $desired_value..."
            sudo sysctl -w kernel.perf_event_paranoid=$desired_value
            echo "Run mode: Setting kptr_restrict to $desired_value..."
            sudo sysctl -w kernel.kptr_restrict=$desired_value
        fi
    else
        echo "SUCCESS: Perf event paranoid is already $current_value or more."
    fi
}

benchmarking_all() {
    local dry_run=$1
    disable_hyperthreading $dry_run
    disable_turbo $dry_run
    performance_scaling_governor $dry_run
    perf_event_paranoid $dry_run
}

benchmarking() {
    benchmarking_all $DRY_RUN
    if [[ $DRY_RUN == "false" ]]; then
        benchmarking_all true
    fi
}

benchmarking
