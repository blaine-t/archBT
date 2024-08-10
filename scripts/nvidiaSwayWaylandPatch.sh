#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd -P -- "$(dirname -- "$0")" && cd ..

# Update packages
paru

# First install sway-git which should install wlroots-git
paru sway-git

# Then install egl-wayland-git
paru egl-wayland-git

# And finally xdg-desktop-portal-wlr-git
paru xdg-desktop-portal-wlr-git

# Add config for portal to make OBS work
mkdir -p ~/.config/xdg-desktop-portal
cp config/programs/portals.conf ~/.config/xdg-desktop-portal

# Add env variable so sway launches instead of hanging
echo 'export WLR_DRM_NO_ATOMIC=1' >> ~/.profile
source ~/.profile
