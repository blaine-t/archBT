#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd -P -- "$(dirname -- "$0")" && cd ..

cat << EOF
This script is used to install programs for after install
This is customized to my LG Gram 15Z90Q-P.AAC6U1 with an i5-1240p running Wayland
It does an unreviewed AUR install of wdisplays so be aware
This version is adapted to Sway

EOF

# Install screen management
sudo pacman -Syu kanshi --noconfirm
echo '1' | paru -a wdisplays --skipreview

# Portal setup
sudo pacman -S xdg-desktop-portal-wlr --noconfirm
echo 'export XDG_CURRENT_DESKTOP=sway' >> ~/.profile

# Install screenshot utilities
sudo pacman -S slurp grim wl-clipboard --noconfirm

# Install notifications
sudo pacman -S mako --noconfirm

# Waybar for good topbar
sudo pacman -S waybar --noconfirm

# Copy over sway config
mkdir -p ~/.config/sway
cp config/dotfiles/sway/config ~/.config/sway

# Theming for sway
sudo pacman -S qt5ct --noconfirm

# QT wayland stuff
sudo pacman -S qt5-wayland qt6-wayland --noconfirm

# Write theming information to .profile
cat << EOF >> ~/.profile
### Backends
#
# This may cause crashes

# GTK
export GDK_BACKEND=wayland
#export CLUTTER_BACKEND=wayland

# Qt (should use wayland by default)
#export QT_QPA_PLATFORM=xcb
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# SDL
#export SDL_VIDEODRIVER=wayland

# Java
export _JAVA_AWT_WM_NONREPARENTING=1

### Theming
#
export QT_QPA_PLATFORMTHEME="qt5ct"

gsettings set org.gnome.desktop.interface cursor-theme capitaine-cursors
gsettings set org.gnome.desktop.interface icon-theme la-capitaine-icon-theme
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark

EOF

source ~/.profile
