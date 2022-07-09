#!/bin/bash

echo 'RECOMMENDED UEFI SETTNGS:'
echo 'PURE UEFI: ENABLED'
echo 'CSM: DISABLED'
echo 'Secure Boot: DISABLED'
echo 'Secure Boot Setup Mode: ENABLED'
echo 'TPM: ENABLED (DISABLED AFTER SECURE BOOT KEY ENROLLED)'
echo 'BIOS PASSWORD: ENABLED'
echo 'USB BOOT: ENABLED (DISABLED AFTER INSTALL)'
sleep 1
echo ''
echo 'Testing network connection and resolution with ping to Archlinux.org'
echo ''
until ping -c1 www.archlinux.org >/dev/null 2>&1; do :; done

# Gather environment variables for use in automated install
read -rp 'Enter installation drive (Ex: /dev/sda or /dev/nvme0n1): ' INSTALL_DRIVE
read -rp 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0n1p1): ' BOOT_PARTITION
read -rp 'Enter root partition (Ex: /dev/sda2 or /dev/nvme0n1p2): ' ROOT_PARTITION
read -rp 'Enter username: ' USER
sleep 1
echo ''
echo 'Example:'
echo 'On a 1TB drive with extra OP space'
echo 'Partition 1 is an EFI system partition (1G)'
echo 'Partition 2 is a linux filesystem (800G)'
echo 'Partition 3 is a linux swap (Double RAM)'
echo 'FREE SPACE is for over-provisioning'
echo ''
read -n 1 -rp 'Press any key to continue'
cfdisk $INSTALL_DRIVE

# Sets up boot partition
clear
fdisk -l $INSTALL_DRIVE
echo ''
fdisk -l $BOOT_PARTITION
echo ''
read -n 1 -rp 'IS THIS THE RIGHT BOOT PARTITION TO FORMAT? [y/N] ' response
echo ''
if [[ "$response" =~ ^([yY])$ ]]
then
    mkfs.fat -c -F 32 -n BOOT $BOOT_PARTITION # Makes boot file system as FAT32 and confirms that sectors are good to use
else
    echo 'Leaving installer, please rerun with correct boot partition.'
	exit
fi

# Sets up root partition
clear
fdisk -l $INSTALL_DRIVE
echo ''
fdisk -l $ROOT_PARTITION
echo ''
echo 'Enter encryption password and confirm and open the partition'
cryptsetup -v --hash sha512 luksFormat $ROOT_PARTITION # Enables encryption on the root partition
cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open $ROOT_PARTITION root # Opens encrypted root partition so it can be formatted and used
mkfs.btrfs -L ARCH /dev/mapper/root # Makes root file system formated to BTRFS 

# Mounts encrypted btrfs partition to /mnt on live ISO
mount /dev/mapper/root /mnt 

# Creates the subvolume setup for the btrfs partition [mruiz42](https://gist.github.com/mruiz42/83d9a232e7592d65d953671409a2aab9)
# Based off of recommendations by [Snapper](https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout) and [OpenSUSE](https://en.opensuse.org/SDB:BTRFS)
btrfs subvolume create /mnt/@ # Mapped to /
btrfs subvolume create /mnt/@home # Mapped to /home
btrfs subvolume create /mnt/@snapshots # Mapped to /.snapshots
btrfs subvolume create /mnt/@var_log # Mapped to /var/log
btrfs subvolume create /mnt/@userCache # Mapped to /home/$USER/.cache
btrfs subvolume create /mnt/@pkgCache # Mapped to /var/cache/pacman/pkg
btrfs subvolume create /mnt/@var_tmp # Mapped to /var/tmp
btrfs subvolume create /mnt/@images # Mapped to /var/lib/libvirt/images
btrfs subvolume create /mnt/@opt # Mapped to /opt
btrfs subvolume create /mnt/@root # Mapped to /root
btrfs subvolume create /mnt/@usr_local # Mapped to /usr/local

umount /mnt # Unmounts after creating subvolumes
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@ /dev/mapper/root /mnt # Mounts our btrfs root subvolume to /mnt with no access time, zstd compression, and TRIM

# We need to make all the directories for our subvolumes
mkdir /mnt/home
mkdir /mnt/.snapshots
mkdir -p /mnt/var/log
mkdir -p /mnt/var/cache/pacman/pkg
mkdir /mnt/var/tmp
mkdir -p /mnt/var/lib/libvirt/images
mkdir /mnt/opt
mkdir /mnt/root
mkdir -p /mnt/usr/local

# We now need to mount all of the subvolumes
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@home /dev/mapper/root /mnt/home
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@snapshots /dev/mapper/root /mnt/.snapshots
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_log /dev/mapper/root /mnt/var/log
mkdir -p /mnt/home/$USER/.cache # Make the home cache directory now that we mounted the home subvol.
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@userCache /dev/mapper/root /mnt/home/$USER/.cache
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@pkgCache /dev/mapper/root /mnt/var/cache/pacman/pkg
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_tmp /dev/mapper/root /mnt/var/tmp
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@images /dev/mapper/root /mnt/var/lib/libvirt/images
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@opt /dev/mapper/root /mnt/opt
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@root /dev/mapper/root /mnt/root
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@usr_local /dev/mapper/root /mnt/usr/local

# Disable copy on write for VM images to help performance for VMs
chattr +C /mnt/var/lib/libvirt/images

# Makes and mounts the boot partition to /boot/EFI and adds the directory ./Linux (since mkinitcpio can't seem to do it by itself)
mkdir -p /mnt/boot/EFI/
mount $BOOT_PARTITION /mnt/boot/EFI
mkdir /mnt/boot/EFI/Linux

# Install "required" packages to our new install
pacstrap /mnt base base-devel linux linux-firmware linux-headers efibootmgr btrfs-progs networkmanager nano git opendoas cryptsetup sbctl linux-zen linux-zen-headers linux-lts linux-lts-headers
read -n 1 -rp 'Do you have an Amd or Intel CPU or Neither? [a/i/N] ' response
if [[ "$response" =~ ^([aA])$ ]]
then
	pacstrap /mnt amd-ucode xf86-video-amdgpu
elif [[ "$response" =~ ^([iI])$ ]]
then
	pacstrap /mnt intel-ucode xf86-video-intel
fi

timedatectl set-ntp true
genfstab -U /mnt >> /mnt/etc/fstab # Create our fstab so the system can mount stuff properly

# Add support for encrypted swap
clear
read -n 1 -rp 'Do you have a swap partition? [y/N] ' response
if [[ "$response" =~ ^([yY])$ ]]
then
    read -rp 'Enter swap partition (Ex: /dev/sda3 or /dev/nvme0n1p3): ' SWAP_PARTITION
	echo '' >> /mnt/etc/crypttab
	echo "swap           $SWAP_PARTITION                                    /dev/urandom           swap,cipher=aes-xts-plain64,size=512" >> /mnt/etc/crypttab
	echo '/dev/mapper/swap				none		swap		sw	0 0' >> /mnt/etc/fstab
fi

echo ''
echo '# git clone https://github.com/blaine-t/archBT'
echo ''
echo 'CLONE THE GITHUB REPO AND THEN CHMOD +x AND THEN RUN 2rootChroot.sh'
arch-chroot /mnt # Changes into root on the new filesystem