read -rp 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0n1p1): ' BOOT_PARTITION
read -rp 'Enter root partition (Ex: /dev/sda2 or /dev/nvme0n1p2): ' ROOT_PARTITION
read -rp 'Enter username: ' USERNAME

# We now need to mount all of the subvolumes
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@home "${ROOT_PARTITION}" /mnt/home
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@snapshots "${ROOT_PARTITION}" /mnt/.snapshots
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_log "${ROOT_PARTITION}" /mnt/var/log
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@userCache "${ROOT_PARTITION}" /mnt/home/"${USERNAME}"/.cache
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@pkgCache "${ROOT_PARTITION}" /mnt/var/cache/pacman/pkg
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@var_tmp "${ROOT_PARTITION}" /mnt/var/tmp
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@images "${ROOT_PARTITION}" /mnt/home/"${USERNAME}"/.local/share/libvirt/images
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@opt "${ROOT_PARTITION}" /mnt/opt
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@root "${ROOT_PARTITION}" /mnt/root
mount -o noatime,commit=120,compress-force=zstd,discard=async,subvol=@usr_local "${ROOT_PARTITION}" /mnt/usr/local