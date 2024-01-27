#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

# Update packages
sudo pacman -Syu --noconfirm

# Install optional dependencies
sudo pacman -S acpid hdparm wireless_tools --noconfirm
sudo systemctl enable --now acpid

# Supress normal keypresses from logs
sudo cp config/acpi/buttons /etc/acpi/events/

# laptop-mode-tools setup
echo '1' | paru -a laptop-mode-tools --skipreview
sudo cp -r config/laptop-mode/* /etc/laptop-mode/

# Turn off watchdog to conserve battery
sudo cp config/modprobe/disable-sp5100-watchdog.conf /etc/modprobe.d/

# Run GPU in powersavings
sudo cp config/modprobe/i915.conf /etc/modprobe.d/

# Disable core dumps
sudo cp config/sysctl/50-coredump.conf /etc/sysctl.d/

# Disable hibernation
sudo cp config/systemd/sleep.conf /etc/systemd/

# Make mouse not accidentally wake up laptop while sleeping
sudo cp config/udev/50-wake-on-device.rules /etc/udev/rules.d/

# Change ioschedulers based on device
sudo cp config/udev/60-ioschedulers.rules /etc/udev/rules.d/

# vm.laptop_mode = 5 investigation

# Compiltation speedup with ccache etc.

# List powersaving config
for i in $(find /sys/devices -name "bMaxPower")
do
    busdir=${i%/*}
    busnum=$(<$busdir/busnum)
    devnum=$(<$busdir/devnum)
    title=$(lsusb -s $busnum:$devnum)
    
    printf "\n\n+++ %s\n  -%s\n" "$title" "$busdir"
    
    for ff in $(find $busdir/power -type f ! -empty 2>/dev/null)
    do
        v=$(cat $ff 2>/dev/null|tr -d "\n")
        [[ ${#v} -gt 0 ]] && echo -e " ${ff##*/}=$v";
        v=;
    done | sort -g;
done;

printf "\n\n\n+++ %s\n" "Kernel Modules"
for mod in $(lspci -k | sed -n '/in use:/s,^.*: ,,p' | sort -u)
do
    echo "+ $mod";
    systool -v -m $mod 2> /dev/null | sed -n "/Parameters:/,/^$/p";
done