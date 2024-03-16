#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

echo 'This script will install Sway. MUST be run as user.'

# Install Sway minimum with pipewire audio, networkmanager, xwayland, wezterm and fuzzel
# Modern internet fonts
sudo pacman -Syu ttf-dejavu ttf-firacode-nerd ttf-liberation adobe-source-han-sans-otc-fonts ttf-hanazono noto-fonts-emoji noto-fonts-cjk --noconfirm
# Old theme
# sudo pacman -S breeze breeze-gtk --noconfirm
# Sound
sudo pacman -S pipewire pipewire-audio pipewire-pulse pipewire-alsa pipewire-v4l2 pipewire-jack wireplumber --noconfirm
systemctl enable --user pipewire
# Sway!
sudo pacman -S sway swaylock swayidle swaybg xorg-xwayland wezterm fuzzel --noconfirm
# Not for my system
# sudo pacman -S iio-sensor-proxy maliit-keyboard switcheroo-control --noconfirm

echo 'This does not include a display manager. If you want one then install GDM or SDDM.'
echo 'You can optionally install my starter programs by running 4_programs.sh AFTER REBOOT. READ IT BEFORE RUNNING IT'
