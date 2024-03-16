=#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd -P -- "$(dirname -- "$0")" && cd ..

cat << EOF
This script is used to install programs for after install on KDE
This is customized to my LG Gram 15Z90Q-P.AAC6U1 with an i5-1240p running Wayland

EOF

# Install audio support
sudo pacman -Syu pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack qpwgraph --noconfirm

# Install display management
sudo pacman -S kscreen --noconfirm

# Install power management
sudo pacman -S powerdevil power-profiles-daemon --noconfirm
# kinfocenter is not required but gives useful info especially about battery
sudo pacman -S kinfocenter --noconfirm

# Portal setup for dolphin in every file picker
sudo pacman -S xdg-desktop-portal-kde --noconfirm
echo 'export XDG_CURRENT_DESKTOP=KDE' >> ~/.profile

# Bluetooth support
sudo pacman -S bluedevil --noconfirm

# Install screenshotter
sudo pacman -S spectacle --noconfirm
