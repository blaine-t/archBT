# This script will install KDE-Plasma

# Update pacman cache
pacman -Syu

if [[ "${DISPLAY_SERVER}" =~ [wW] ]]; then
  pacman -S plasma-wayland-session --noconfirm
elif [[ "${DISPLAY_SERVER}" =~ [xX] ]]; then
  pacman -S xorg-server xf86-input-evdev --noconfirm
else
  pacman -S xorg-server xf86-input-evdev plasma-wayland-session --noconfirm
fi

pacman -S pipewire-jack wireplumber ttf-bitstream-vera phonon-qt5-gstreamer --noconfirm
pacman -S dolphin dolphin-plugins konsole khotkeys plasma-desktop plasma-nm  pipewire-pulse pipewire-alsa --noconfirm

echo 'This does not include a display manager. If you want one then install GDM or SDDM-git from the AUR for wayland support.'
echo 'If you are on X then you can install most display managers. Recommended SDDM'