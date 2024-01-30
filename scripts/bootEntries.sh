# Use this file if your boot entries got messed up or wiped but all the data is still there
# Add boot entries for standard linux and the fallback image
read -p 'Enter boot partition (Ex: /dev/sda1 or /dev/nvme0n1p1): ' BOOT_PARTITION
efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux' --loader 'Linux\linux.efi' --verbose
efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux-lts' --loader 'Linux\linux-lts.efi' --verbose
efibootmgr --create --disk ${BOOT_PARTITION} --label 'Linux-zen' --loader 'Linux\linux-zen.efi' --verbose
