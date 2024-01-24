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
It does multiple unreviewed AUR installs so be aware

EOF

read -rp 'Enter git username: ' USERNAME
read -rp 'Enter git email: ' EMAIL

# Prep sudo
sudo -l

## Git config
git config --global user.name ${USERNAME}
git config --global user.email ${EMAIL}
## GPG support
cp secrets/.gnupg ~/.gnupg
gpg --list-keys --keyid-format=long
read -rp 'Enter git pubkey: ' PUBKEYID
git config --global user.signingkey ${PUBKEYID}
git config --global commit.gpgsign true

# Update packages
paru -Syu --noconfirm

# Oh my bash install
echo '1' | paru -a oh-my-bash-git --skipreview --noconfirm
cat /usr/share/oh-my-bash/bashrc >> ~/.bashrc

# Install Firefox
sudo pacman -S firefox plasma-browser-integration --noconfirm
# Extensions
sudo pacman -S firefox-extension-ublock-origin firefox-decentraleyes firefox-dark-reader --noconfirm
echo 'export MOZ_ENABLE_WAYLAND=1' >> ~/.profile
# Firefox config changes:
# widget.use-xdg-desktop-portal.mime-handler = 1
# widget.use-xdg-desktop-portal.file-pickers = 1
# media.hardwaremediakeys.enabled = false
# browser.quitShortcut.disabled = true

# KDE Plasma Intel audio fix
sudo pacman -S pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack qpwgraph --noconfirm
sudo cp config/audiofix.conf /etc/modprobe.d/audiofix.conf

# Install display management
sudo pacman -S kscreen --noconfirm

# Install power management
sudo pacman -S powerdevil power-profiles-daemon powertop --noconfirm
# kinfocenter is not required but gives useful info especially about battery
sudo pacman -S kinfocenter --noconfirm

# Portal setup for dolphin in every file picker
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-kde --noconfirm
echo 'export GTK_USE_PORTAL=1' >> ~/.profile
echo 'export XDG_CURRENT_DESKTOP=KDE' >> ~/.profile

# Install Obsidian
sudo pacman -S obsidian --noconfirm
echo 'export OBSIDIAN_USE_WAYLAND=1' >> ~/.profile

# Chrony setup
sudo pacman -S chrony --noconfirm
sudo systemctl enable --now chronyd
sudo cp config/chrony.conf /etc/chrony.conf

# Bluetooth support
sudo pacman -S bluez bluez-utils bluedevil --noconfirm
sudo systemctl enable --now bluetooth

# Yubico authenticator install
echo '1' | paru -a yubico-authenticator-bin --skipreview --noconfirm
sudo pacman -S pcsclite --noconfirm
sudo systemctl enable --now pcscd

# Discord install
sudo pacman -S discord ttf-symbola --noconfirm

# VS Code Install
echo '1' | paru -a visual-studio-code-bin --skipreview --noconfirm
cp config/code-flags.conf ~/.config/code-flags.conf


# Bash history file unlimited support
echo 'export HISTSIZE="toInfinity"' >> ~/.bashrc
echo 'export HISTFILESIZE="andBeyond"' >> ~/.bashrc
echo ". ${HOME}/.bashrc" >> ~/.profile # Needed for TTY login

# VPN Setup
# Wireguard
nmcli connection import type wireguard file secrets/wg*
nmcli connection modify wg-home connect.autoconnect no
# OpenVPN
sudo pacman -S networkmanager-openvpn --noconfirm
nmcli connection import type openvpn file secrets/ovpn*

# Install screenshot
sudo pacman -S spectacle --noconfirm

# Install Spotify xWayland to have media support
sudo pacman -S spotify-launcher --noconfirm

# Install Steam (32-bit xwayland cause Steam is ancient dinosaur)
sudo pacman -S steam --noconfirm

# Install Slack
# Login Fix: https://stackoverflow.com/questions/70867064/signing-into-slack-desktop-not-working-on-4-23-0-64-bit-ubuntu
echo '1' | paru -a slack-electron --skipreview --noconfirm
cp desktops/slack.desktop ~/.local/share/applications

# Install Teams (It somehow just works)
echo '1' | paru -a teams-for-linux-bin --skipreview --noconfirm
cp desktops/teams-for-linux.desktop ~/.local/share/applications

# Node setup
echo '1' | paru -a volta-bin --skipreview --noconfirm
volta setup
source ~/.bashrc
volta install node@latest
volta install node@lts
volta install npm
volta install pnpm
volta install yarn@1
volta install yarn
volta install nodemon
volta install typescript

# Python setup
sudo pacman -S python-pip --noconfirm

# Java setup
sudo pacman -S jdk-openjdk --noconfirm
echo '1' | paru -a eclipse-java --skipreview --noconfirm
# Fix font aliasing in GTK apps (needs relogin)
sudo pacman -S xdg-desktop-portal-gtk --noconfirm
# To setup gpg signing go to preferences and lookup gpg and switch from bouncy castle to an external gpg executable /usr/bin/gpg

# Install CUPS with max compatibility
sudo pacman -S cups cups-pdf ghostscript gsfonts foomatic-db-engine foomatic-db foomatic-db-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds gutenprint foomatic-db-gutenprint-ppds --noconfirm
sudo systemctl enable --now cups.socket

# Give styling options to apps
sudo pacman -S kde-gtk-config gnome-settings-daemon gsettings-desktop-schemas gsettings-qt --noconfirm

# Dictionary for apps to use for spellcheck
sudo pacman -S hunspell hunspell-en_US --noconfirm

# Install [chaotic AUR](https://aur.chaotic.cx/)
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm
cat << EOF | sudo tee -a /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

EOF

# Install chromium with video accel for video decoding
# Syu because just added chaotic-aur
sudo pacman -Syu libva-utils vdpauinfo chromium-wayland-vaapi --noconfirm
cp desktops/chromium.desktop ~/.local/share/applications
# Intel only
echo 'export VDPAU_DRIVER=va_gl' >> ~/.profile
echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.profile
source ~/.profile

# libvirt install
# Win11 install guide: https://linustechtips.com/topic/1379063-windows-11-in-virt-manager/
yes | sudo pacman -S virt-manager qemu-desktop dnsmasq iptables-nft swtpm
sudo usermod -aG libvirt ${USER}

sudo sed -i 's/#unix_sock_group/unix_sock_group/g' /etc/libvirt/libvirtd.conf
sudo sed -i 's/#unix_sock_rw/unix_sock_rw/g' /etc/libvirt/libvirtd.conf
sudo sed -i "s/#user = \"libvirt-qemu\"/user = \"${USER}\"/g" /etc/libvirt/qemu.conf
sudo sed -i "s/#group = \"libvirt-qemu\"/group = \"${USER}\"/g" /etc/libvirt/qemu.conf

echo 'In virt-manager you can remove the system QEMU connection and add a User Session QEMU connections'
