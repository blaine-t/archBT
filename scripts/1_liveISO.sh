#!/bin/bash

# Bash Strict Mode [aaron maxwell](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
set -euo pipefail
IFS=$'\n\t'

# Force script PWD to be where the script is located up a directory
cd ${0%/*}
cd ..

# Provide recommended settings
cat << EOF
RECOMMENDED BIOS SETTINGS:
PURE UEFI: ENABLED
CSM: DISABLED
Secure Boot: DISABLED
Secure Boot Setup Mode: ENABLED
TPM: ENABLED (DISABLED AFTER SECURE BOOT KEY ENROLLED)
BIOS PASSWORD: ENABLED
USB BOOT: ENABLED (DISABLED AFTER INSTALL)

EOF

# Check internet connection
echo -e 'Testing network connection and resolution with ping to Archlinux.org\n'
until ping -c1 www.archlinux.org >/dev/null 2>&1; do :; done

# Gather environment variables for use in install
read -rp 'Enter installation drive (Ex: /dev/sda or /dev/nvme0n1): ' INSTALL_DRIVE

# Set up partitioning
cat << EOF

Example:
On a 1TB drive with extra OP space
Partition 1 is an EFI system partition (1G)
Partition 2 is a linux filesystem (800G)
Partition 3 is a linux swap (Double RAM)
FREE SPACE is for over-provisioning

EOF
read -n 1 -rp 'Press any key to enter cfdisk to partition drive'
cfdisk ${INSTALL_DRIVE}

# Set up boot partition
clear
fdisk -l ${INSTALL_DRIVE}
echo
read -rp 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0n1p1): ' BOOT_PARTITION
read -rp 'Enter root partition (Ex: /dev/sda2 or /dev/nvme0n1p2): ' ROOT_PARTITION
echo
fdisk -l ${BOOT_PARTITION}
echo
read -n 1 -rp 'IS THIS THE RIGHT BOOT PARTITION TO FORMAT? [y/N] ' response
echo
if [[ ${response} =~ [yY] ]]; then
    # Makes boot file system as FAT32 and confirms that sectors are good to use
    mkfs.fat -c -F 32 -n BOOT ${BOOT_PARTITION}
else
    echo 'Leaving installer, please rerun with correct boot partition.'
    exit
fi

# Set up root partition
clear
fdisk -l ${INSTALL_DRIVE}
echo
fdisk -l ${ROOT_PARTITION}
echo

# Set up encryption
# [Encryption page](https://bcachefs.org/Encryption/)
read -n 1 -rp 'Do you want to use bcachefs encryption? [y/N] ' ENCRYPTION
echo
if [[ ${ENCRYPTION} =~ [yY] ]]; then
    bcachefs format --encrypted --discard ${ROOT_PARTITION}
    bcachefs unlock ${ROOT_PARTITION}
else
    bcachefs format --discard ${ROOT_PARTITION}
fi

# Mounts bcachefs partition to /mnt on live ISO
mount ${ROOT_PARTITION} /mnt

# Makes and mounts the boot partition to /boot/EFI and adds the directory ./Linux (since mkinitcpio can't seem to do it by itself)
mkdir -p /mnt/boot/EFI/
mount ${BOOT_PARTITION} /mnt/boot/EFI
mkdir /mnt/boot/EFI/Linux

# Install "required" packages to new install
pacstrap /mnt base base-devel linux-firmware mkinitcpio bcachefs-tools efibootmgr iptables-nft networkmanager git nano posix

# Prompt for kernels
echo 'You will be prompted for 3 differnt kernels. You can select any/multiple as long as you pick at least one. (LTS CURRENTLY DOESNT SUPPORT BCACHEFS)'
read -n 1 -rp 'Do you want the linux-lts kernel? [y/N] ' LTS
echo
if [[ ${LTS} =~ [yY] ]]; then
    cp mkinitcpio/presets/linux-lts.preset /mnt/etc/mkinitcpio.d/
    pacstrap /mnt linux-lts linux-lts-headers
fi
read -n 1 -rp 'Do you want the linux-zen kernel? [y/N] ' ZEN
echo
if [[ ${ZEN} =~ [yY] ]]; then
    cp mkinitcpio/presets/linux-zen.preset /mnt/etc/mkinitcpio.d/
    pacstrap /mnt linux-zen linux-zen-headers
fi

if [[ ! ${LTS} =~ [yY] ]] && [[ ! ${ZEN} =~ [yY] ]]; then
    echo "Installing Linux kernel since others weren't selected"
    LINUX=Y
    cp mkinitcpio/presets/linux.preset /mnt/etc/mkinitcpio.d/
    pacstrap /mnt linux linux-headers
else
    read -n 1 -rp 'Do you want the linux kernel? [y/N] ' LINUX
    echo
    if [[ ${LINUX} =~ [yY] ]]; then
        cp mkinitcpio/presets/linux.preset /mnt/etc/mkinitcpio.d/
        pacstrap /mnt linux linux-headers
    fi
fi

# Prompt for doas
read -n 1 -rp 'Do you want doas to replace sudo? [y/N] ' DOAS
echo
if [[ ${DOAS} =~ [yY] ]]; then
    pacstrap /mnt opendoas
fi

# Prompt for secure boot
read -n 1 -rp 'Do you want secure boot support? [y/N] ' SECURE
echo
if [[ ${SECURE} =~ [yY] ]]; then
    pacstrap /mnt sbctl
fi

# Prompt for X11/Wayland
read -n 1 -rp 'Do you want X11 or Wayland or Both? [x/w/B] ' DISPLAY_SERVER
echo

# Prompt for microcode
read -n 1 -rp 'Do you have an Amd or Intel CPU or Neither? [a/i/N] ' response
echo
if [[ ${response} =~ [aA] ]]; then
    pacstrap /mnt amd-ucode
    elif [[ ${response} =~ [iI] ]]; then
    pacstrap /mnt intel-ucode
fi

# Prompt for 32 bit support
read -n 1 -rp 'Do you want 32-bit support (e.g. Steam)? [y/N] ' LIB32
echo
if [[ ${LIB32} =~ [yY] ]]; then
    # Uncomment multilib repository to install apps like steam
    sed -i -z -e 's/#\[multilib\]\n#/\[multilib\]\n/g' /etc/pacman.conf
    sed -i -z -e 's/#\[multilib\]\n#/\[multilib\]\n/g' /mnt/etc/pacman.conf
fi

# Prompt for accelerated video decoding
read -n 1 -rp 'Do you want accelerated video decoding (e.g. VA-API & VDPAU)? [y/N] ' VACCEL
echo
read -n 1 -rp 'Do you have an Amd, nVidia or Intel GPU or Neither? [a/v/i/N] ' GPU
echo
if [[ ${GPU} =~ [aA] ]];  then
    # Add DRI driver for 3D acceleration with mesa
    # Add vulkan support with vulkan-radeon
    pacstrap /mnt mesa vulkan-radeon
    
    # If using X then add 2D acceleration support in xorg
    if [[ ! ${DISPLAY_SERVER} =~ [wW] ]]; then
        pacstrap /mnt xf86-video-amdgpu
    fi
    
    # If 32 bit support add 32 bit packages
    if [[ ${LIB32} =~ [yY] ]]; then
        pacstrap /mnt lib32-mesa lib32-vulkan-radeon
    fi
    
    # If accelerated video decoding add packages
    if [[ ${VACCEL} =~ [yY] ]]; then
        pacstrap /mnt libva-mesa-driver mesa-vdpau
        # If 32 bit support also add 32 bit accelerated video decoding
        if [[ ${LIB32} =~ [yY] ]]; then
            pacstrap /mnt lib32-libva-mesa-driver lib32-mesa-vdpau
        fi
    fi
    
    elif [[ ${GPU} =~ [vV] ]]; then
    # Install Nvidia-DKMS to have support for all kernels no matter what
    pacstrap /mnt nvidia-dkms
    
    # If 32 bit support add 32 bit packages
    if [[ ${LIB32} =~ [yY] ]]; then
        pacstrap /mnt lib32-nvidia-utils
    fi
    echo 'VA-API support is offered through AUR package that has to be installed in user space'
    echo 'https://wiki.archlinux.org/title/Hardware_video_acceleration'
    elif [[ ${GPU} =~ [iI] ]]; then
    # Add DRI driver for 3D acceleration with mesa
    # Add vulkan support with vulkan-intel
    pacstrap /mnt mesa vulkan-intel intel-media-driver libvdpau-va-gl intel-gpu-tools
    
    # If using X then add 2D acceleration support in xorg
    if [[ ! ${DISPLAY_SERVER} =~ [wW] ]]; then
        pacstrap /mnt xorg-server
    fi
    
    # If 32 bit support add 32 bit packages
    if [[ ${LIB32} =~ [yY] ]]; then
        pacstrap /mnt lib32-mesa lib32-vulkan-intel
    fi
fi

# Set clock using internet
timedatectl set-ntp true

# Add support for swap
clear
read -n 1 -rp 'Do you have a swap partition? [y/N] ' response
echo
if [[ ${response} =~ [yY] ]]; then
    read -rp 'Enter swap partition (Ex: /dev/sda3 or /dev/nvme0n1p3): ' SWAP_PARTITION
    echo
    if [[ ${ENCRYPTION} =~ [yY] ]]; then
        # Add cryptsetup to support encrypted swap partition until bcachefs supports swapfile
        pacstrap /mnt cryptsetup
        echo >> /mnt/etc/crypttab
        echo "swap           ${SWAP_PARTITION}                                    /dev/urandom           swap,cipher=aes-xts-plain64,size=512" >> /mnt/etc/crypttab
        echo '/dev/mapper/swap				none		swap		sw	0 0' >> /mnt/etc/fstab
    else
        mkswap -L SWAP ${SWAP_PARTITION}
        swapUUID=$(blkid -o value -s UUID ${SWAP_PARTITION})
        {
            echo '# Swap partition'
            echo "UUID=${swapUUID}	none	swap	sw	0 0"
            echo
        } >> /mnt/etc/fstab
    fi
fi

# Create our fstab so the system can mount stuff properly
genfstab -U /mnt >> /mnt/etc/fstab

# Copy install script over
mkdir -p /mnt/archBT
cp -r ./* /mnt/archBT

# Export variables for other scripts to use
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
echo 'cd to /archBT/scripts and run 2_rootChroot.sh'
arch-chroot /mnt
