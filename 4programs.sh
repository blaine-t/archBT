#!/bin/bash

# Use to install programs for after install

# Update packages
sudo pacman -Syu

# Install [Paru](https://github.com/Morganamilo/paru#installation)
# Used to easily download and install applications from the AUR
sudo pacman -S --needed base-devel
cd ~
mkdir build
cd build
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

# Install Librewolf
paru librewolf-bin
echo "export MOZ_ENABLE_WAYLAND=1" >> ~/.profile
source ~/.profile

# KDE Plasma Intel audio fix
cp config/audiofix.conf /etc/modprobe.d/audiofix.conf

# Install [chaotic AUR](https://aur.chaotic.cx/)
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo "[chaotic-aur]  
Include = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf

# Install display management
sudo pacman -S kscreen

# Install power management
sudo pacman -S tlp powerdevil powertop
sudo systemctl enable --now tlp
# kinfocenter is not required but gives useful info especially about battery
sudo pacman -S kinfocenter

# Install chromium with video accel for video decoding ADD INTEL TO SCRIPT
sudo pacman -S libva-utils vdpauinfo
export VDPAU_DRIVER=va_gl
echo "export VDPAU_DRIVER=va_gl" >> ~/.profile
source ~/.profile
paru chromium-wayland-vaapi
cp desktops/chrominum.desktop ~/.local/share/applications

# Chrony setup
sudo pacman -S chrony
sudo systemctl enable --now chronyd
sudo cp config/chrony.conf /etc/chrony.conf

# Bluetooth support
sudo pacman -S bluez bluez-utils bluedevil
sudo systemctl enable --now bluetooth

# Yubico authenticator install
paru yubico-authenticator
sudo pacman -S pcsclite
sudo systemctl enable --now pcscpd

# Discord install
sudo pacman -S discord noto-fonts-cjk noto-fonts-emoji ttf-symbola

# VS Code Install 
sudo pacman -S ttf-firacode-nerd
paru visual-studio-code-bin
cp config/code-flags.conf ~/.config/code-flags.conf
## Git config
git config --global user.name USERNAME
git config --global user.email EMAIL
## GPG support
cp secrets/.gnupg ~/.gnupg
gpg --list-keys --keyid-format=long
git config --global user.signingkey PUBKEYID
git config --global commit.gpgsign true


# Bash history file unlimited support
echo 'export HISTSIZE="toInfinity"' >> ~/.bashrc
echo 'export HISTFILESIZE="andBeyond"' >> ~/.bashrc
echo ". $HOME/.bashrc" >> ~/.profile # Needed for TTY login
source ~/.bashrc

# VPN Setup
# Wireguard
nmcli connection import type wireguard file secrets/wg*
nmcli connection modify wg-home connect.autoconnect no
# OpenVPN
sudo pacman -S networkmanager-openvpn
nmcli connection import type openvpn file secrets/ovpn*

# Install screenshot ADD TO SCRIPT
sudo pacman -S spectacle

# MATLAB install
# https://github.com/Rubo3/matlab-aur
# https://wiki.archlinux.org/title/MATLAB
# https://www.mathworks.com/downloads/
# Download the Linux package from Matlab site
# Follow instructions on aur package to build
# To launch if on Intel copy desktop file
cp desktops/matlab.desktop ~/.local/share/applications

# Portal setup for dolphin in every file picker
sudo pacman -S xdg-desktop-portal xdg-desktop-portal-kde
echo "export GTK_USE_PORTAL=1" >> ~/.profile
source ~/.profile

# Install Obsidian
sudo pacman -S obsidian
echo "export OBSIDIAN_USE_WAYLAND=1" >> ~/.profile
source ~/.profile

# Install Spotify xWayland to have media support
sudo pacman -S spotify-launcher
paru spicetify-cli
paru spicetify-themes-git
cp config/config-xpui.ini ~/.config/spicetify/config-xpui.ini

# Install Steam (32-bit xwayland cause Steam is ancient dinosaur)
sudo pacman -S steam

# Install Slack
# Login Fix: https://stackoverflow.com/questions/70867064/signing-into-slack-desktop-not-working-on-4-23-0-64-bit-ubuntu
paru slack-electron
cp desktops/slack.desktop ~/.local/share/applications

# Install Teams (It somehow just works)
paru teams-for-linux
cp desktops/teams-for-linux.desktop ~/.local/share/applications

# Node setup
paru volta-bin
volta setup
source ~/.bashrc
volta install node@latest
volta install node@lts
volta install npm
volta install pnpm
volta install yarn@1
volta insall yarn
volta install nodemon
volta install typescript

# Rust setup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Python setup
sudo pacman -S python-pip

# Java setup
sudo pacman -S jdk-openjdk jre-openjdk jre-openjdk-headless
paru eclipse-java
# Fix font aliasing in GTK apps (needs relogin)
sudo pacman -S xdg-desktop-portal-gtk
# To setup gpg signing go to preferences and lookup gpg and switch from bouncy castle to an external gpg executable /usr/bin/gpg

# libvirt install
# Win11 install guide: https://linustechtips.com/topic/1379063-windows-11-in-virt-manager/
sudo pacman -S virt-manager qemu-desktop dnsmasq iptables-nft swtpm
sudo usermod -aG libvirt $USER
# Uncomment unix_sock_group and unix_sock_rw in /etc/libvirt/libvirtd.conf
# Uncomment user and group and set them to your username in /etc/libvirt/qemu.conf
# In virt-manager you can remove the system QEMU connection and add a User Session QEMU connections

# Oh my bash install
paru oh-my-bash-git
cat /usr/share/oh-my-bash/bashrc >> ~/.bashrc
source ~/.bashrc