cd "${0%/*}" # Forces script to be in same directory as linux.presets

# Gather required info for installing boot "manager"
read -p 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0np1): ' BOOT_PARTITION
read -p 'Enter root partition (Ex: /dev/sda2 or /dev/nvme0n1p2): ' ROOT_PARTITION

# Sets the local time
read -p 'Enter timezone for system (Ex: America/Chicago): ' TIMEZONE
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

# Sets locale config to add US locale
sed -i 's,#en_US.UTF-8,en_US.UTF-8,g' /etc/locale.gen 
locale-gen

# Sets local language to English
echo 'LANG=en_US.UTF-8' > /etc/locale.conf 

# Prompts for hostname and shows username
user=$(ls /home*/)
echo "Username: $user"
read -p 'Hostname: ' hostname

# Sets up hostname
echo "$hostname" > /etc/hostname
echo '# Static table lookup for hostnames' > /etc/hosts
echo '# See hosts(5) for details.' >> /etc/hosts
echo '' >> /etc/hosts
echo '127.0.0.1   localhost' >> /etc/hosts
echo '::1         localhost' >> /etc/hosts
echo "127.0.0.1   $hostname" >> /etc/hosts

# Adds multilib repository to install apps like steam
echo '' >> /etc/pacman.conf
echo '[multilib]' >> /etc/pacman.conf
echo 'Include = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf

# Adds btrfs, btrfs recovery, and encryption support to mkinitcpio hooks
sed -i 's,MODULES=(),MODULES=(btrfs),g' /etc/mkinitcpio.conf 
sed -i 's,BINARIES=(),BINARIES=(btrfs),g' /etc/mkinitcpio.conf 
sed -i 's,block filesystems keyboard,block encrypt filesystems keyboard,g' /etc/mkinitcpio.conf 

# Speedup compiling for makepkg: https://gist.github.com/frandieguez/0b13bd58148679aa9955
sed -i 's,#MAKEFLAGS="-j2",MAKEFLAGS="-j$(nproc)",g' /etc/makepkg.conf
sed -i "s,PKGEXT='.pkg.tar.zst',PKGEXT='.pkg.tar',g" /etc/makepkg.conf

# Creates the userspace user with a password and adds them to appropriate groups
useradd $user
usermod -aG wheel,audio,video,optical,storage $user
chown "$user":"$user" -R "/home/$user"
echo 'Set the user'
passwd $user

# Setup doas (a sudo replacement)
pacman -Rns sudo --noconfirm
echo 'permit persist :wheel' > /etc/doas.conf # Allows users in wheel group to execute doas
ln -s /bin/doas /bin/sudo # Fix paru and other application issues and allows for user to type sudo instaed of doas and still works
echo '' >> /etc/bash.bashrc
echo 'complete -cf doas' >> /etc/bash.bashrc # Allows for proper autocomplete of doas

# Enable network control on boot
systemctl enable NetworkManager

# Setup boot "manager"
# Grab the UUID of encrypted and decrypted root partition and use it in kernel parameters for boot [Reddit Post](https://www.reddit.com/r/archlinux/comments/m4aa0u/luks_encryption_with_efistub_boot/)
EUUID=$(blkid -s UUID -o value $ROOT_PARTITION)
RUUID=$(blkid -s UUID -o value /dev/mapper/root)
echo "cryptdevice=UUID=$EUUID:root:allow-discards root=UUID=$RUUID rw rootflags=subvol=@ quiet loglevel=3 bgrt_disable" > /etc/kernel/cmdline

# Replace the default linux Unified Kernel Config with our new one
rm /etc/mkinitcpio.d/linux.preset
rm /etc/mkinitcpio.d/linux-lts.preset
rm /etc/mkinitcpio.d/linux-zen.preset
cp ./linux.preset /etc/mkinitcpio.d/
cp ./linux-lts.preset /etc/mkinitcpio.d/
cp ./linux-zen.preset /etc/mkinitcpio.d/

# Add boot entries for standard linux and the fallback image
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux-fallback' --loader 'Linux\linux-fallback.efi' --verbose
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux' --loader 'Linux\linux.efi' --verbose
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux-lts-fallback' --loader 'Linux\linux-lts-fallback.efi' --verbose
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux-lts' --loader 'Linux\linux-lts.efi' --verbose
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux-zen-fallback' --loader 'Linux\linux-zen-fallback.efi' --verbose
efibootmgr --create --disk $BOOT_PARTITION --label 'Linux-zen' --loader 'Linux\linux-zen.efi' --verbose

# Regenerate the initramfs
mkinitcpio -P

# Setup secure boot
sbctl create-keys
sbctl enroll-keys
sbctl sign -s /boot/EFI/Linux/linux-fallback.efi
sbctl sign -s /boot/EFI/Linux/linux.efi
sbctl sign -s /boot/EFI/Linux/linux-lts-fallback.efi
sbctl sign -s /boot/EFI/Linux/linux-lts.efi
sbctl sign -s /boot/EFI/Linux/linux-zen-fallback.efi
sbctl sign -s /boot/EFI/Linux/linux-zen.efi
sbctl list-files
sbctl status

echo ''
echo 'If you messed up your user password now is the time to fix that.'
echo 'Otherwise you can just Ctrl+D reboot or chmod +x and run 3wmde.sh to install a minimal KDE Plasma Desktop install'