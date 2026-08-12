#!/usr/bin/env bash

set -e

# Make it boot like a workstation
sudo systemctl set-default graphical.target
sudo reboot
