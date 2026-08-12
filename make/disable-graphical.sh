#!/usr/bin/env bash

set -e

# Make it boot like a server
sudo systemctl set-default multi-user.target
sudo reboot
