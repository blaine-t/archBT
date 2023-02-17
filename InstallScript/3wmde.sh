# This script will install KDE-Plasma

# Update pacman cache
pacman -Syu

if [[ "${DISPLAY_SERVER}" =~ [wW] ]]; then
    pacman -S plasma-wayland-session
elif [[ "${DISPLAY_SERVER}" =~ [xX] ]]; then
    pacman -S xorg-server xf86-input-evdev
else
    pacman -S xorg-server xf86-input-evdev plasma-wayland-session
fi

pacman -S dolphin dolphin-plugins konsole khotkeys plasma-desktop plasma-nm pipewire-jack pipewire-pulse pipewire-alsa wireplumber ttf-bitstream-vera phonon-qt5-gstreamer

echo 'This does not include a display manager. If you want one then install GDM or SDDM-git from the AUR for wayland support.'
echo 'If you are on X then you can install most display managers. Recommended SDDM'