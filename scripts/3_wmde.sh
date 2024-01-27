#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

echo 'This script will install KDE-Plasma and paru (for phonon-qt5-mpv from the AUR). MUST be run as user.'

# Update pacman cache and install Rust for paru
sudo pacman -Syu rustup --noconfirm
rustup default stable

# Install dependencies for given display server
if [[ ! ${DISPLAY_SERVER} =~ [xX] ]]; then
    sudo pacman -S plasma-wayland-session --noconfirm
fi
if [[ ! ${DISPLAY_SERVER} =~ [wW] ]]; then
    sudo pacman -S xorg-server xf86-input-evdev --noconfirm
fi

# Install [Paru](https://github.com/Morganamilo/paru#installation)
# Used to easily download and install applications from the AUR
sudo pacman -S --needed base-devel
cd ~
mkdir build
cd build
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
rm -rf ~/build

# Install KDE Plasma minimum with mpv phonon backend and pipewire audio with networkmanager and default file manager and terminal
sudo pacman -S pipewire-jack wireplumber --noconfirm
sudo pacman -S mpv --noconfirm
echo 'Installing phonon-qt5-mpv from the AUR'
echo '1' | paru -a phonon-qt5-mpv --skipreview
sudo pacman -S ttf-dejavu ttf-firacode-nerd ttf-liberation adobe-source-han-sans-otc-fonts ttf-hanazono noto-fonts-emoji noto-fonts-cjk --noconfirm
sudo pacman -S breeze breeze-gtk --noconfirm
sudo pacman -S dolphin dolphin-plugins konsole khotkeys plasma-desktop plasma-nm plasma-pa pipewire-pulse pipewire-alsa pipewire-v4l2 --noconfirm
sudo pacman -S baloo-widgets ffmpegthumbs kdegraphics-thumbnailers kdenetwork-filesharing print-manager xwaylandvideobridge xsettingsd --noconfirm
# Not for my system
# sudo pacman -S iio-sensor-proxy maliit-keyboard switcheroo-control --noconfirm

echo 'This does not include a display manager. If you want one then install GDM or SDDM-git from the AUR for wayland support.'
echo 'If you are on X then you can install most display managers. Recommended SDDM'
echo 'You can optionally install my starter programs by running 4_programs.sh AFTER REBOOT. READ IT BEFORE RUNNING IT'
