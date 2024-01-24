#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

# Update packages
sudo pacman -Syu --noconfirm

# Install optional dependencies
sudo pacman -S acpid hdparm --noconfirm
sudo systemctl enable --now acpid

# Supress normal keypresses from logs
cp config/acpi/* /etc/acpi/events/

# laptop-mode-tools setup
echo '1' | paru -a laptop-mode-tools --skipreview --noconfirm
cp -r config/laptop-mode/* /etc/laptop-mode/
