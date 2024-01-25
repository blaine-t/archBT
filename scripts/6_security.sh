#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

# Update packages
sudo pacman -Syu --noconfirm

# Install and configure ufw
sudo pacman -S ufw --noconfirm
sudo systemctl enable --now ufw
sudo ufw default deny
sudo ufw logging off

# Allow VPNs to work through firewall
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.bak
sudo cp configs/ufw/before.rules /etc/ufw/before.rules
sudo sed -i 's,#net/ipv4/ip_forward=1,net/ipv4/ip_forward=1,g' /etc/ufw/sysctl.conf
sudo sed -i 's,#net/ipv6/conf/default/forwarding=1,net/ipv6/conf/default/forwarding=1,g' /etc/ufw/sysctl.conf
sudo sed -i 's,#net/ipv6/conf/all/forwarding=1,net/ipv6/conf/all/forwarding=1,g' /etc/ufw/sysctl.conf


# Make Docker not create vulnerabilities when using UFW
echo '1' | paru -a ufw-docker --skipreview --noconfirm
sudo ufw-docker install

# Install UFW blocklist to protect from malicious IPs
# https://github.com/poddmo/ufw-blocklist
# Complicated to do and harms battery life so not doing for now

# Turn on ufw and enable it
sudo ufw enable

# Disable responding to pings
sudo cp configs/sysctl/51-ignore-pings.conf /etc/sysctl.d/
