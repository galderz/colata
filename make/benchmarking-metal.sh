#!/usr/bin/env bash

set -e

DRY_RUN=true

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
            echo "Run mode: disable hyper threading via command line"
            echo off | sudo tee /sys/devices/system/cpu/smt/control
        fi
    fi
}

disable_turbo() {
    local no_turbo="/sys/devices/system/cpu/intel_pstate/no_turbo"
    local desired_value="1"

    if [ -f "$no_turbo" ]; then
      local no_turbo_value=$(cat $no_turbo)
      # Check if the value is 1
      if [ "$no_turbo_value" == "$desired_value" ]; then
        echo "SUCCESS: No turbo boost is 1. Nothing to do."
      else
        echo "ERROR: No turbo boost is not 1. It's $no_turbo_value."
        if [[ $dry_run == "true" ]]; then
            echo "Dry-run mode: No turbo boost would be enabled if not in dry-run mode."
        else
            echo "Run mode: No turbo boost to $desired_value value..."
            echo "$desired_value" | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null
        fi
      fi
    else
	echo "SUCCESS: Not an intel machine."
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

# Shutdown all unnecessary services for benchmarking
stop_services() {
    stop_service "docker.socket"
    stop_service "docker.service"
    stop_service "nix-daemon.socket"
    stop_service "nix-daemon.service"
    stop_service "firewalld"
    stop_service "incus"
    stop_service "virtqemud"
    killall ssh-agent || true

    systemctl status nix-daemon.socket || true
    systemctl status nix-daemon.service || true
    systemctl status docker.socket || true
    systemctl status docker.service || true
    systemctl status firewalld || true
    systemctl status incus || true
    systemctl status virtqemud || true
}

stop_service() {
    local service_name=$1

    # Check the LoadState of the service
    local load_state=$(systemctl show -p LoadState "${service_name}" | cut -d'=' -f2)

    # Check if the service is loaded
    if [[ "$load_state" == "loaded" ]]; then
        echo "${service_name} is loaded. Stopping it..."
        sudo systemctl stop "${service_name}"
    else
        echo "${service_name} is not loaded."
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
        stop_services
    fi
}

benchmarking
