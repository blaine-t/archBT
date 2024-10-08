#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd -P -- "$(dirname -- "$0")" && cd ..

# Sets the local time
read -rp 'Enter timezone for system (Ex: America/Chicago): ' TIMEZONE
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# Sets locale config to add US locale
sed -i 's,#en_US.UTF-8,en_US.UTF-8,g' /etc/locale.gen
locale-gen

# Sets local language to English
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# Prompts for hostname
read -rp 'Hostname: ' HOSTNAME

# Sets up hostname and hosts file
echo ${HOSTNAME} > /etc/hostname
cat << EOF > /etc/hosts
# Static table lookup for hostnames
# See hosts(5) for details.

# IPv4
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}

# IPv6
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

EOF

# Speedup compiling for makepkg: https://gist.github.com/frandieguez/0b13bd58148679aa9955
sed -i 's,#MAKEFLAGS="-j2",MAKEFLAGS="-j$(nproc)",g' /etc/makepkg.conf
sed -i "s,PKGEXT='.pkg.tar.zst',PKGEXT='.pkg.tar',g" /etc/makepkg.conf

# Speedup pacman with parallel downloads and add color
sed -i "s,#ParallelDownloads = 5,ParallelDownloads = $(nproc),g" /etc/pacman.conf
sed -i 's,#Color,Color,g' /etc/pacman.conf

# Creates the userspace user with a password and adds them to appropriate groups
read -rp 'Enter username: ' USERNAME
useradd -m ${USERNAME}
usermod -aG wheel,audio,video,optical,storage ${USERNAME}
echo "Set the user's"
passwd ${USERNAME}

# Setup doas (a sudo replacement if user wanted)
if [[ ${DOAS} =~ [yY] ]]; then
    echo 'Cannot remove sudo since dependency of base-devel. If you want to delete create a pseudo package'
    # Allows users in wheel group to execute doas
    echo 'permit persist setenv { XAUTHORITY LANG LC_ALL } :wheel' > /etc/doas.conf
    # Fix paru and other application issues and allows for user to type sudo instaed of doas and still works
    # ln -s /bin/doas /bin/sudo (Do this if you remove sudo)
    echo >> /etc/bash.bashrc
    # Allows for proper autocomplete of doas
    echo 'complete -cf doas' >> /etc/bash.bashrc
else
    echo '%wheel      ALL=(ALL:ALL) ALL' >> /etc/sudoers
fi

# Enable network control on boot
systemctl enable NetworkManager

# Remove mkinitcpio hooks for consolefont to silence warning
if [[ ${ENCRYPTION} =~ [yY] ]]; then
    sed -i 's/consolefont block filesystems/block filesystems/g' /etc/mkinitcpio.conf
fi

# Add in mkinitcpio modules for Nvidia drivers
if [[ ${GPU} =~ [vV] ]]; then
    sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
fi

# Set cmdline parameters for kernel
PRUUID=$(blkid -s PARTUUID -o value ${ROOT_PARTITION})
# ASPM powersupersave might not be working TODO: Look into adding optional lockdown=integrity pcie_aspm=force acpi_osi=\"Windows 2015\" acpi_osi=! pcie_aspm.policy=powersupersave but for now taken out
echo -n "root=/dev/disk/by-partuuid/${PRUUID} rw quiet bgrt_disable nmi_watchdog=0 drm.vblankoffdelay=1" > /etc/kernel/cmdline

# Add cmdline args for Nvidia drm
if [[ ${GPU} =~ [vV] ]]; then
    echo ' nvidia_drm.modeset=1 nvidia_drm.fbdev=1' >> /etc/kernel/cmdline
fi

# Add boot entries for kernels
boot_entries=0
query='Which entry should be in the 0 position in order '
if [[ ${LINUX} =~ [yY] ]]; then
    boot_entries=$((boot_entries + 1))
    query+='Linu[X], '
fi
if [[ ${LTS} =~ [yY] ]]; then
    boot_entries=$((boot_entries + 1))
    query+='[L]ts, '
fi
if [[ ${ZEN} =~ [yY] ]]; then
    boot_entries=$((boot_entries + 1))
    query+='[Z]en, '
fi

# Update amount of boot entries left
query="${query/[[:digit:]]/${boot_entries}}"

while [[ ${boot_entries} -gt 0 ]]; do
    read -n 1 -rp ${query} response
    echo
    if [[ ${response} =~ [xX] ]]; then
        efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux' --loader 'Linux\linux.efi' --verbose
        # Remove entry from list
        query=${query//'Linu[X], '/ }
        boot_entries=$((boot_entries - 1))
        elif [[ ${response} =~ [lL] ]]; then
        efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux-lts' --loader 'Linux\linux-lts.efi' --verbose
        # Remove entry from list
        query=${query//'[L]ts, '/ }
        boot_entries=$((boot_entries - 1))
        elif [[ ${response} =~ [zZ] ]]; then
        efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux-zen' --loader 'Linux\linux-zen.efi' --verbose
        # Remove entry from list
        query=${query//'[Z]en, '/ }
        boot_entries=$((boot_entries - 1))
    fi
    # Update amount of boot entries left
    query="${query/[[:digit:]]/${boot_entries}}"
done

# Copy over bcachefs hook and install
# NEEDED UNTIL BCACHEFS TOOLS ARE FIXED
# cp mkinitcpio/hooks/bcachefs /etc/initcpio/hooks/
# cp mkinitcpio/install/bcachefs /etc/initcpio/install/

# Pin Bcachefs-tools until 1.6.4 bugs fixed
# pacman -U https://archive.archlinux.org/packages/b/bcachefs-tools/bcachefs-tools-3%3A1.6.3-1-x86_64.pkg.tar.zst

# Regenerate the initramfs
mkinitcpio -P

# Setup secure boot
if [[ ${SECURE} =~ [yY] ]]; then
    sbctl create-keys
    if (! sbctl enroll-keys); then
        # Since NVIDIA is a pain we have to use Microsoft keys
        # https://www.youtube.com/watch?v=iYWzMvlj2RQ
        # For other GPUs we can use our custom ones most of the time
        echo 'Failed to enroll keys.'
        echo 'If you have an NVIDIA GPU you will need to use Microsoft keys.'
        echo 'Other system configs also only work with Microsoft keys.'
        read -n 1 -rp 'USE MICROSOFT KEYS? [y/N] ' response
        echo
        if [[ ${response} =~ [yY] ]]; then
            if (! sbctl enroll-keys --microsoft); then
                echo 'Failed to enroll keys.'
                echo 'Skipping secure boot setup.'
                echo "Perhaps you weren't in setup mode?"
            fi
        else
            echo 'Skipping secure boot setup.'
        fi
    fi
    if [[ ${LINUX} =~ [yY] ]]; then
        sbctl sign -s /boot/EFI/Linux/linux.efi
    fi
    if [[ ${LTS} =~ [yY] ]]; then
        sbctl sign -s /boot/EFI/Linux/linux-lts.efi
    fi
    if [[ ${ZEN} =~ [yY] ]]; then
        sbctl sign -s /boot/EFI/Linux/linux-zen.efi
    fi
    sbctl list-files
    sbctl status
fi

cat << EOF

If you messed up your user password now is the time to fix that.
The cmdline supplied in this script is intended for laptops. If you don't need laptop powersavings feel free to delete after bgrt_disable.
Otherwise you can just Ctrl+D reboot or run 3_kde.sh to install a minimal KDE Plasma Desktop or 3_sway.sh to install a minimal Sway Desktop.
Switching to user...

EOF

# Copy archBT over to user and switch to user
mkdir -p /home/${USERNAME}/archBT
cd ..
mv archBT /home/${USERNAME}
chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/archBT
cd /home/${USERNAME}/archBT/scripts
su ${USERNAME}
