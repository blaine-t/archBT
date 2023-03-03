#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

cd "${0%/*}" # Forces script to be in same directory as linux.presets

# Sets the local time
read -rp 'Enter timezone for system (Ex: America/Chicago): ' TIMEZONE
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# Sets locale config to add US locale
sed -i 's,#en_US.UTF-8,en_US.UTF-8,g' /etc/locale.gen 
locale-gen

# Sets local language to English
echo 'LANG=en_US.UTF-8' > /etc/locale.conf 

# Prompts for hostname and shows username
USER=$(ls /home*/)
read -rp 'Hostname: ' HOSTNAME

# Sets up hostname
echo "$HOSTNAME" > /etc/hostname
{
  echo '# Static table lookup for hostnames'
  echo '# See hosts(5) for details.'
  echo ''
  echo '127.0.0.1   localhost'
  echo '::1         localhost'
  echo "127.0.0.1   $HOSTNAME"
} >> /etc/hosts
# Adds btrfs and btrfs recovery support to mkinitcpio hooks
sed -i 's,MODULES=(),MODULES=(btrfs),g' /etc/mkinitcpio.conf 
sed -i 's,BINARIES=(),BINARIES=(btrfs),g' /etc/mkinitcpio.conf

# If user selected encryption then add the hook
if [[ "$ENCRYPTION" =~ [yY] ]]; then
  sed -i 's,block filesystems keyboard,block encrypt filesystems keyboard,g' /etc/mkinitcpio.conf 
fi

# Speedup compiling for makepkg: https://gist.github.com/frandieguez/0b13bd58148679aa9955
sed -i 's,#MAKEFLAGS="-j2",MAKEFLAGS="-j$(nproc)",g' /etc/makepkg.conf
sed -i "s,PKGEXT='.pkg.tar.zst',PKGEXT='.pkg.tar',g" /etc/makepkg.conf

# Creates the userspace user with a password and adds them to appropriate groups
useradd "${USERNAME}"
usermod -aG wheel,audio,video,optical,storage "${USERNAME}"
chown "${USERNAME}":"${USERNAME}" -R "/home/${USERNAME}"
echo 'Set the user'
passwd "${USERNAME}"

# Setup doas (a sudo replacement if user wanted)
if [[ "$DOAS" =~ [yY] ]]; then
  echo 'Cannot remove sudo since dependency of base-devel. If you want to delete create a pseudo package'
  # Allows users in wheel group to execute doas
  echo 'permit persist setenv { XAUTHORITY LANG LC_ALL } :wheel' > /etc/doas.conf
  # Fix paru and other application issues and allows for user to type sudo instaed of doas and still works
  # ln -s /bin/doas /bin/sudo (Do this if you remove sudo)
  echo '' >> /etc/bash.bashrc
  # Allows for proper autocomplete of doas
  echo 'complete -cf doas' >> /etc/bash.bashrc
else
  echo '%wheel      ALL=(ALL:ALL) ALL' >> /etc/sudoers
fi

# Enable network control on boot
systemctl enable NetworkManager

# Setup boot "manager"
# Grab the UUID of encrypted and decrypted root partition and use it in kernel parameters for boot [Reddit Post](https://www.reddit.com/r/archlinux/comments/m4aa0u/luks_encryption_with_efistub_boot/)
if [[ "$ENCRYPTION" =~ [yY] ]]; then
  EUUID=$(blkid -s UUID -o value "${ORIGINAL_ROOT_PARTITION}")
  RUUID=$(blkid -s UUID -o value /dev/mapper/root)
  echo "cryptdevice=UUID=$EUUID:root:allow-discards root=UUID=$RUUID rw rootflags=subvol=@ quiet bgrt_disable" > /etc/kernel/cmdline
else
  PRUUID=$(blkid -s PARTUUID -o value "${ROOT_PARTITION}")
  echo "root=PARTUUID=${PRUUID} rw rootflags=subvol=@ quiet bgrt_disable" > /etc/kernel/cmdline
fi

# Add boot entries for standard linux and the fallback image
# AND
# Replace the default linux Unified Kernel Config with our new one
boot_entries=0
query='Which entry should be in the 0 position in order '
if [[ "$LINUX" =~ [yY] ]]; then
  rm /etc/mkinitcpio.d/linux.preset
  cp ./linux.preset /etc/mkinitcpio.d/
  boot_entries=$((boot_entries + 1))
  query+="linu[X], "
fi
if [[ "$LTS" =~ [yY] ]]; then
  rm /etc/mkinitcpio.d/linux-lts.preset
  cp ./linux-lts.preset /etc/mkinitcpio.d/
  boot_entries=$((boot_entries + 1))
  query+="[L]ts, "
fi
if [[ "$ZEN" =~ [yY] ]]; then
  rm /etc/mkinitcpio.d/linux-zen.preset
  cp ./linux-zen.preset /etc/mkinitcpio.d/
  boot_entries=$((boot_entries + 1))
  query+="[Z]en, "
fi
# Replace trailing comma
query=${query%, }"? "

# Update amount of boot entries left
query="${query/[[:digit:]]/$boot_entries}"

while [[ "${boot_entries}" -gt 0 ]]; do
  read -n 1 -rp "${query}" response
  echo ''
  if [[ "$response" =~ [xX] ]]; then
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux-fallback' --loader 'Linux\linux-fallback.efi' --verbose
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux' --loader 'Linux\linux.efi' --verbose
    # Remove entry from list
    query=${query//"Linu[X], "/ }
    boot_entries=$((boot_entries - 1))
  elif [[ "$response" =~ [lL] ]]; then
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux-lts-fallback' --loader 'Linux\linux-lts-fallback.efi' --verbose
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux-lts' --loader 'Linux\linux-lts.efi' --verbose
    # Remove entry from list
    query=${query//"[L]ts, "/ }
    boot_entries=$((boot_entries - 1))
  elif [[ "$response" =~ [zZ] ]]; then
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux-zen-fallback' --loader 'Linux\linux-zen-fallback.efi' --verbose
    efibootmgr --create --disk "${BOOT_PARTITION}" --label 'Linux-zen' --loader 'Linux\linux-zen.efi' --verbose
    # Remove entry from list
    query=${query//"[Z]en, "/ }
    boot_entries=$((boot_entries - 1))
  fi
  # Update amount of boot entries left
  query="${query/[[:digit:]]/$boot_entries}"
done

# Regenerate the initramfs
mkinitcpio -P

# Setup secure boot
if [[ "$SECURE" =~ [yY] ]]; then
  sbctl create-keys
  if [[ "$GPU" =~ ^([vV])$ ]]; then
    # Since NVIDIA is a pain we have to use microsoft keys
    sbctl enroll-keys --microsoft
  else
    # For other GPUs we can use our custom ones most of the time
    sbctl enroll-keys
  fi
  if [[ "$LINUX" =~ [yY] ]]; then
    sbctl sign -s /boot/EFI/Linux/linux-fallback.efi
    sbctl sign -s /boot/EFI/Linux/linux.efi
  fi
  if [[ "$LTS" =~ [yY] ]]; then
    sbctl sign -s /boot/EFI/Linux/linux-lts-fallback.efi
    sbctl sign -s /boot/EFI/Linux/linux-lts.efi
  fi
  if [[ "$ZEN" =~ [yY] ]]; then
    sbctl sign -s /boot/EFI/Linux/linux-zen-fallback.efi
    sbctl sign -s /boot/EFI/Linux/linux-zen.efi
  fi
  sbctl list-files
  sbctl status
fi

echo ''
echo 'If you messed up your user password now is the time to fix that.'
echo 'Otherwise you can just Ctrl+D reboot or chmod +x and run 3wmde.sh to install a minimal KDE Plasma Desktop install'
