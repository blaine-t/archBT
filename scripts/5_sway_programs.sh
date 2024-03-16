#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

cat << EOF
This script is used to install programs for after install
This is customized to my LG Gram 15Z90Q-P.AAC6U1 with an i5-1240p running Wayland
It does an unreviewed AUR install of wdisplays so be aware
This version is adapted to Sway

EOF

# Install screen management
sudo pacman -Syu kanshi
echo '1' | paru -a wdisplays --skipreview

# Portal setup
sudo pacman -S xdg-desktop-portal-wlr --noconfirm
echo 'export XDG_CURRENT_DESKTOP=sway' >> ~/.profile

# Install screenshot utilities
sudo pacman -S slurp grim wl-clipboard --noconfirm

# Install notifications
sudo pacman -S mako --no-confirm

# Waybar for good topbar
sudo pacman -S waybar --no-confirm

# Copy over sway config
cp config/dotfiles/sway/config
