# This script will install KDE-Plasma for native Wayland
pacman -Syu dolphin dolphin-plugins konsole khotkeys plasma-desktop plasma-nm plasma-wayland-session pipewire-jack pipewire-pulse pipewire-alsa wireplumber ttf-bitstream-vera phonon-qt5-gstreamer sddm sddm-kcm xorg-server xf86-input-evdev
systemctl enable sddm