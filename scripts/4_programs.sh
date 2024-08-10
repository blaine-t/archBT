#!/bin/bash

# Force script PWD to be where the script is located up a directory
cd -P -- "$(dirname -- "$0")" && cd ..

cat << EOF
This script is used to install programs for after install
This is customized to my LG Gram 15Z90Q-P.AAC6U1 with an i5-1240p running Wayland
It does multiple unreviewed AUR installs so be aware
It is currently written for a KDE install

EOF

# VPN Setup (Do before strict mode)
sudo systemctl enable --now systemd-resolved
# Wireguard
mkdir -p secrets/.gnupg
mkdir -p secrets/.ssh
cd secrets
for file in *.conf; do
    nmcli connection import type wireguard file ${file}
    nmcli connection modify ${file%.*} connect.autoconnect no
    nmcli connection down ${file%.*}
done
# OpenVPN
sudo pacman -S networkmanager-openvpn --noconfirm
for file in *.ovpn; do
    nmcli connection import type openvpn file ${file}
done
# Back to main directory
cd ..

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

read -rp 'Enter git username: ' USERNAME
read -rp 'Enter git email: ' EMAIL

# Git config
git config --global init.defaultbranch main
git config --global user.name ${USERNAME}
git config --global user.email ${EMAIL}
# GPG support
cp -r secrets/.gnupg ~
gpg --list-keys --keyid-format=long
read -rp 'Enter git pubkey: ' PUBKEYID
git config --global user.signingkey ${PUBKEYID}
git config --global commit.gpgsign true

# Install audio support with Intel audiofix
read -rp 'Are you using an Intel audio and video codec? ' INTEL
if [[ ${INTEL} =~ [yY] ]]; then
    echo "!---!"
    echo "Audio fix is untested. If it doesn't work properly for you delete or modify the file at /etc/modprobe.d/audiofix.conf"
    echo "!---!"
    sudo cp config/modprobe/audiofix.conf /etc/modprobe.d/audiofix.conf

    # Intel only VDPAU support
    echo 'export VDPAU_DRIVER=va_gl' >> ~/.profile
    # echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.profile
    source ~/.profile
fi

# Prep sudo
sudo -l

# SSH secrets copy
cp -r secrets/.ssh ~

# Reflector setup
sudo pacman -Syu reflector --noconfirm
sudo cp config/programs/reflector.conf /etc/xdg/reflector/reflector.conf
sudo systemctl enable --now reflector

# Install Rust for paru
sudo pacman -Syu rustup --noconfirm
rustup default stable
echo 'export CARGO_HOME="$HOME/.cargo' >> ~/.bashrc
echo 'export PATH="$CARGO_HOME/bin:$PATH' >> ~/.bashrc

# Install [Paru](https://github.com/Morganamilo/paru#installation)
# Used to easily download and install applications from the AUR
sudo pacman -S --needed base-devel
mkdir build
cd build
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd ../..
rm -rf build

# Update packages
paru -Syu --noconfirm

# Oh my bash install
echo '1' | paru -a oh-my-bash-git --skipreview
cat /usr/share/oh-my-bash/bashrc >> ~/.bashrc

# Install Firefox
sudo pacman -S firefox --noconfirm
# Extensions
sudo pacman -S firefox-ublock-origin firefox-dark-reader --noconfirm
# Firefox cache in ram (UNSTABLE NOT RECOMMENDED)
# sudo pacman -S profile-sync-daemon --noconfirm
# systemctl --user enable --now psd
# Firefox config changes:
# widget.use-xdg-desktop-portal.mime-handler = 1
# widget.use-xdg-desktop-portal.file-pickers = 1
# media.hardwaremediakeys.enabled = false
# browser.quitShortcut.disabled = true
# extensions.pocket.enabled = false
# browser.cache.disk.enable = false
# browser.cache.memory.enable = true
# browser.cache.memory.capacity = 1048576
# Check here after install to make sure you have everything working: https://wiki.archlinux.org/title/Firefox

# Portal setup
sudo pacman -S xdg-desktop-portal --noconfirm
echo 'export GTK_USE_PORTAL=1' >> ~/.profile

# Install Obsidian
sudo pacman -S obsidian --noconfirm
echo 'export OBSIDIAN_USE_WAYLAND=1' >> ~/.profile

# Chrony setup
sudo pacman -S chrony --noconfirm
sudo systemctl enable --now chronyd
sudo cp config/programs/chrony.conf /etc/chrony.conf
echo '1' | paru -a networkmanager-dispatcher-chrony --skipreview

# Bluetooth support
sudo pacman -S bluez bluez-utils --noconfirm
sudo systemctl enable --now bluetooth

# Yubico authenticator install
sudo pacman -S pcsclite --noconfirm
sudo systemctl enable --now pcscd
echo '1' | paru -a yubico-authenticator-bin --skipreview

# VS Code Install
echo '1' | paru -a visual-studio-code-bin --skipreview
cp config/programs/code-flags.conf ~/.config/code-flags.conf

# Bash history file unlimited support
echo 'export HISTSIZE="toInfinity"' >> ~/.bashrc
echo 'export HISTFILESIZE="andBeyond"' >> ~/.bashrc
echo ". ${HOME}/.bashrc" >> ~/.profile # Needed for TTY login

# Last .profile edit made. Source it
source ~/.profile

# Install Spotify xWayland to have media support
sudo pacman -S spotify-launcher --noconfirm

# Install Steam (32-bit xwayland cause Steam is ancient dinosaur)
sudo pacman -S steam --noconfirm

# Install Slack
# Login Fix: https://stackoverflow.com/questions/70867064/signing-into-slack-desktop-not-working-on-4-23-0-64-bit-ubuntu
echo '1' | paru -a slack-electron --skipreview
mkdir -p ~/.local/share/applications
cp desktops/slack.desktop ~/.local/share/applications

# Install Teams (It somehow just works)
# echo '1' | paru -a teams-for-linux-bin --skipreview
# cp desktops/teams-for-linux.desktop ~/.local/share/applications

# Node setup
echo '1' | paru -a volta-bin --skipreview
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
echo '1' | paru -a eclipse-java --skipreview
# Fix font aliasing in GTK apps (needs relogin)
sudo pacman -S xdg-desktop-portal-gtk --noconfirm
# To setup gpg signing go to preferences and lookup gpg and switch from bouncy castle to an external gpg executable /usr/bin/gpg

# Fixes mkinitcpio missing firmware
echo '1' | paru -a upd72020x-fw --skipreview

# Install CUPS with max compatibility
sudo pacman -S cups cups-pdf ghostscript gsfonts foomatic-db-engine foomatic-db foomatic-db-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds gutenprint foomatic-db-gutenprint-ppds --noconfirm
sudo systemctl enable --now cups.socket

# Dictionary for apps to use for spellcheck
sudo pacman -S hunspell hunspell-en_US --noconfirm

# Gnome Keyring for secrets
sudo pacman -S gnome-keyring --noconfirm

# Add my favorite task manager and info app
sudo pacman -S btop fastfetch --noconfirm

# KDE Connect for phone integration
# sudo pacman -S kdeconnect --noconfirm

# Clean out pacman cache
sudo pacman -S pacman-contrib --noconfirm
sudo systemctl enable --now paccache.timer

# Install chromium with video accel for video decoding
# Syu because just added chaotic-aur
# sudo pacman -Syu libva-utils vdpauinfo chromium-wayland-vaapi --noconfirm
# cp desktops/chromium.desktop ~/.local/share/applications

# libvirt install
# Win11 install guide: https://linustechtips.com/topic/1379063-windows-11-in-virt-manager/
sudo pacman -S virt-manager qemu-desktop dnsmasq swtpm --noconfirm
sudo usermod -aG libvirt ${USER}

sudo sed -i 's/#unix_sock_group/unix_sock_group/g' /etc/libvirt/libvirtd.conf
sudo sed -i 's/#unix_sock_rw/unix_sock_rw/g' /etc/libvirt/libvirtd.conf
sudo sed -i "s/#user = \"libvirt-qemu\"/user = \"${USER}\"/g" /etc/libvirt/qemu.conf
sudo sed -i "s/#group = \"libvirt-qemu\"/group = \"${USER}\"/g" /etc/libvirt/qemu.conf

echo 'In virt-manager you can remove the system QEMU connection and add a User Session QEMU connections'

# Install [chaotic AUR](https://aur.chaotic.cx/)
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm
cat << EOF | sudo tee -a /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

EOF

# Update Chaotic AUR database
sudo pacman -Syu
