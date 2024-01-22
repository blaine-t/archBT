#!/bin/bash

echo 'This script will install KDE-Plasma and paru (for phonon-qt5-mpv from the AUR). MUST be run as user.'

# Update pacman cache
sudo pacman -Syu

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
makepkg -si
rm -r ~/build/paru
rm -r ~/build

# Install KDE Plasma minimum with mpv phonon backend and pipewire audio with networkmanager and default file manager and terminal
sudo pacman -S mpv --no-confirm
echo 'Installing phonon-qt5-mpv from the AUR'
echo "1" | paru phonon-qt5-mpv --skipreview
sudo pacman -S pipewire-jack wireplumber ttf-bitstream-vera --noconfirm
sudo pacman -S dolphin dolphin-plugins konsole khotkeys plasma-desktop plasma-nm plasma-pa pipewire-pulse pipewire-alsa --noconfirm

echo 'This does not include a display manager. If you want one then install GDM or SDDM-git from the AUR for wayland support.'
echo 'If you are on X then you can install most display managers. Recommended SDDM'
