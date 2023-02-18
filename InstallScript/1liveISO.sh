#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located
cd "${0%/*}" 

# Provide recommended settings
echo 'RECOMMENDED UEFI SETTNGS:'
echo 'PURE UEFI: ENABLED'
echo 'CSM: DISABLED'
echo 'Secure Boot: DISABLED'
echo 'Secure Boot Setup Mode: ENABLED'
echo 'TPM: ENABLED (DISABLED AFTER SECURE BOOT KEY ENROLLED)'
echo 'BIOS PASSWORD: ENABLED'
echo 'USB BOOT: ENABLED (DISABLED AFTER INSTALL)'
sleep 1

# Check internet connection
echo ''
echo 'Testing network connection and resolution with ping to Archlinux.org'
echo ''
until ping -c1 www.archlinux.org >/dev/null 2>&1; do :; done

# Gather environment variables for use in install
read -rp 'Enter installation drive (Ex: /dev/sda or /dev/nvme0n1): ' INSTALL_DRIVE
read -rp 'Enter username: ' USERNAME
sleep 1

# Set up partitioning
echo ''
echo 'Example:'
echo 'On a 1TB drive with extra OP space'
echo 'Partition 1 is an EFI system partition (1G)'
echo 'Partition 2 is a linux filesystem (800G)'
echo 'Partition 3 is a linux swap (Double RAM)'
echo 'FREE SPACE is for over-provisioning'
echo ''
read -n 1 -rp 'Press any key to continue'
cfdisk "${INSTALL_DRIVE}"

# Set up boot partition
clear
fdisk -l "${INSTALL_DRIVE}"
echo ''
read -rp 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0n1p1): ' BOOT_PARTITION
read -rp 'Enter root partition (Ex: /dev/sda2 or /dev/nvme0n1p2): ' ROOT_PARTITION
echo ''
fdisk -l "${BOOT_PARTITION}"
echo ''
read -n 1 -rp 'IS THIS THE RIGHT BOOT PARTITION TO FORMAT? [y/N] ' response
echo ''
if [[ "$response" =~ ^([yY])$ ]]; then
	# Makes boot file system as FAT32 and confirms that sectors are good to use
    mkfs.fat -c -F 32 -n BOOT "${BOOT_PARTITION}"
else
    echo 'Leaving installer, please rerun with correct boot partition.'
	exit
fi

# Set up root partition
clear
fdisk -l "$INSTALL_DRIVE"
echo ''
fdisk -l "${ROOT_PARTITION}"
echo ''

# Set up encryption
read -n 1 -rp 'Do you want LUKS2 Full Disk Encryption? [y/N] ' ENCRYPTION
if [[ "$ENCRYPTION" =~ [yY] ]]; then
	echo 'Enter encryption password and confirm and open the partition'
	# Enables encryption on the root partition with SHA512 since standard is SHA256 and there is no harm going SHA512
	cryptsetup -v --hash sha512 luksFormat "${ROOT_PARTITION}"
	# Opens encrypted root partition so it can be formatted and used
	cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open "${ROOT_PARTITION}" root
	ROOT_PARTITION='/dev/mapper/root'
fi

# Makes root file system formated to BTRFS 
mkfs.btrfs -f -L ARCH "${ROOT_PARTITION}"

# Mounts btrfs partition to /mnt on live ISO
mount "${ROOT_PARTITION}" /mnt 

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

# Unmounts after creating subvolumes
umount /mnt
# Mounts btrfs root subvolume to /mnt with no access time, zstd compression, and TRIM
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@ "${ROOT_PARTITION}" /mnt

# We need to make all the directories for our subvolumes
mkdir /mnt/home/
mkdir /mnt/.snapshots
mkdir -p /mnt/var/log
mkdir -p /mnt/var/cache/pacman/pkg
mkdir -p /mnt/var/tmp
mkdir -p /mnt/var/lib/libvirt/images
mkdir /mnt/opt
mkdir /mnt/root
mkdir -p /mnt/usr/local

# We now need to mount all of the subvolumes
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@home "${ROOT_PARTITION}" /mnt/home
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@snapshots "${ROOT_PARTITION}" /mnt/.snapshots
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_log "${ROOT_PARTITION}" /mnt/var/log
# Create cache directory after mounting home
mkdir -p /mnt/home/"${USERNAME}"/.cache
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@userCache "${ROOT_PARTITION}" /mnt/home/"${USERNAME}"/.cache
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@pkgCache "${ROOT_PARTITION}" /mnt/var/cache/pacman/pkg
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_tmp "${ROOT_PARTITION}" /mnt/var/tmp
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@images "${ROOT_PARTITION}" /mnt/var/lib/libvirt/images
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@opt "${ROOT_PARTITION}" /mnt/opt
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@root "${ROOT_PARTITION}" /mnt/root
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@usr_local "${ROOT_PARTITION}" /mnt/usr/local

# Disable copy on write for VM images to help performance for VMs (May or may not work)
chattr +C /mnt/var/lib/libvirt/images

# Makes and mounts the boot partition to /boot/EFI and adds the directory ./Linux (since mkinitcpio can't seem to do it by itself)
mkdir -p /mnt/boot/EFI/
mount "$BOOT_PARTITION" /mnt/boot/EFI
mkdir /mnt/boot/EFI/Linux

# Install "required" packages to new install
pacstrap /mnt base base-devel linux-firmware efibootmgr btrfs-progs networkmanager git nano

# Check for secure boot
if [[ "$ENCRYPTION" =~ [yY] ]]; then
	pacstrap /mnt cryptsetup
fi

# Prompt for kernels
echo 'You will be prompted for 3 differnt kernels. You can select any/multiple as long as you pick at least one.'
read -n 1 -rp 'Do you want linux-lts kernel? [y/N] ' LTS
echo ''
if [[ "$LTS" =~ ^([yY])$ ]]; then
	pacstrap /mnt linux-lts linux-lts-headers
fi
read -n 1 -rp 'Do you want linux-zen kernel? [y/N] ' ZEN
echo ''
if [[ "$ZEN" =~ ^([yY])$ ]]; then
	pacstrap /mnt linux-zen linux-zen-headers
fi

if [[ ! "$LTS" =~ ^([yY])$ ]] && [[ ! "$ZEN" =~ ^([yY])$ ]]; then
	echo "Installing Linux kernel since others weren't selected"
	LINUX=Y
	pacstrap /mnt linux linux-headers
else
	read -n 1 -rp 'Do you want linux kernel? [y/N] ' LINUX
	echo ''
	if [[ "$LINUX" =~ ^([yY])$ ]]; then
		pacstrap /mnt linux linux-headers
	fi
fi

# Prompt for doas
read -n 1 -rp 'Do you want doas to replace sudo? [y/N] ' DOAS
echo ''
if [[ "$DOAS" =~ ^([yY])$ ]]; then
	pacstrap /mnt opendoas
fi

# Prompt for secure boot
read -n 1 -rp 'Do you want secure boot support? [y/N] ' SECURE
echo ''
if [[ "$SECURE" =~ ^([yY])$ ]]; then
	pacstrap /mnt sbctl
fi

# Prompt for X11/Wayland
read -n 1 -rp 'Do you want X11 or Wayland or Both? [x/w/B] ' DISPLAY_SERVER
echo ''
read -n 1 -rp 'Do you have an Amd or Intel CPU or Neither? [a/i/N] ' response
echo ''
if [[ "$response" =~ ^([aA])$ ]]; then
	pacstrap /mnt amd-ucode
elif [[ "$response" =~ ^([iI])$ ]]; then
	pacstrap /mnt intel-ucode
fi

# Prompt for 32 bit support
read -n 1 -rp 'Do you want 32-bit support (e.g. Steam)? [y/N] ' LIB32
echo ''
if [[ "$LIB32" =~ ^([yY])$ ]]; then
	# Adds multilib repository to install apps like steam
	{
  echo ''
	echo '[multilib]'
	echo 'Include = /etc/pacman.d/mirrorlist'
  } | tee -a /etc/pacman.conf /mnt/etc/pacman.conf
fi

# Prompt for accelerated video decoding
read -n 1 -rp 'Do you want accelerated video decoding (e.g. VA-API & VDPAU)? [y/N] ' VACCEL
echo ''
read -n 1 -rp 'Do you have an Amd, nVidia or Intel CPU or Neither? [a/v/i/N] ' GPU
echo ''
if [[ "$GPU" =~ ^([aA])$ ]];  then
	# Add DRI driver for 3D acceleration with mesa
	# Add vulkan support with vulkan-radeon
	pacstrap /mnt mesa vulkan-radeon
	
	# If using X then add 2D acceleration support in xorg
	if [[ ! "$DISPLAY_SERVER" =~ ^([wW])$ ]]; then
		pacstrap /mnt xf86-video-amdgpu
	fi

	# If 32 bit support add 32 bit packages
	if [[ "$LIB32" =~ ^([yY])$ ]]; then
		pacstrap /mnt lib32-mesa lib32-vulkan-radeon
	fi

	# If accelerated video decoding add packages
	if [[ "$VACCEL" =~ ^([yY])$ ]]; then
		pacstrap /mnt libva-mesa-driver mesa-vdpau
		# If 32 bit support also add 32 bit accelerated video decoding
		if [[ "$LIB32" =~ ^([yY])$ ]]; then
			pacstrap /mnt lib32-libva-mesa-driver lib32-mesa-vdpau
		fi
	fi

elif [[ "$GPU" =~ ^([vV])$ ]]; then
	# Install Nvidia-DKMS to have support for all kernels no matter what
	pacstrap /mnt nvidia-dkms

	# If 32 bit support add 32 bit packages
	if [[ "$LIB32" =~ ^([yY])$ ]]; then
		pacstrap /mnt lib32-nvidia-utils
	fi
	echo 'VA-API support is offered through AUR package that has to be installed in user space'
	echo 'https://wiki.archlinux.org/title/Hardware_video_acceleration'
elif [[ "$GPU" =~ ^([iI])$ ]]; then
	# Add DRI driver for 3D acceleration with mesa
	# Add vulkan support with vulkan-intel
	pacstrap /mnt mesa vulkan-intel
	
	# If using X then add 2D acceleration support in xorg
	if [[ ! "$DISPLAY_SERVER" =~ ^([wW])$ ]]; then
		pacstrap /mnt xf86-video-intel
	fi

	# If 32 bit support add 32 bit packages
	if [[ "$LIB32" =~ ^([yY])$ ]]; then
		pacstrap /mnt lib32-mesa
	fi

	echo 'For video encoding/decoding Intel is a bit picky so follow the arch wiki to add support:'
	echo 'https://wiki.archlinux.org/title/Hardware_video_acceleration'
fi

# Set clock using internet
timedatectl set-ntp true

# Create our fstab so the system can mount stuff properly
genfstab -U /mnt >> /mnt/etc/fstab

# Add support for swap
clear
read -n 1 -rp 'Do you have a swap partition? [y/N] ' response
echo ''
if [[ "$response" =~ ^([yY])$ ]]; then
  read -rp 'Enter swap partition (Ex: /dev/sda3 or /dev/nvme0n1p3): ' SWAP_PARTITION
  echo ''
	if [[ "$ENCRYPTION" =~ [yY] ]]; then
		echo '' >> /mnt/etc/crypttab
		echo "swap           $SWAP_PARTITION                                    /dev/urandom           swap,cipher=aes-xts-plain64,size=512" >> /mnt/etc/crypttab
		echo '/dev/mapper/swap				none		swap		sw	0 0' >> /mnt/etc/fstab
	else
		mkswap "$SWAP_PARTITION"
		swapUUID=$(blkid -o value -s UUID "$SWAP_PARTITION")
		{
		  echo '# Swap partition'
		  echo "UUID=${swapUUID}	none	swap	sw	0 0"
      echo ''
		} >> /mnt/etc/fstab
  fi
fi

# Copy install script over
mkdir -p /mnt/archBT/InstallScript
cp ./* /mnt/archBT/InstallScript

# Export variables for other scripts to use
export USERNAME
export BOOT_PARTITION
export ROOT_PARTITION
export ENCRYPTION
export DOAS
export LINUX
export LTS
export ZEN
export SECURE
export DISPLAY_SERVER
export GPU

# Changes into root on the new filesystem
echo 'CD to /archBT/INstallScript and run 2rootChroot.sh'
arch-chroot /mnt
