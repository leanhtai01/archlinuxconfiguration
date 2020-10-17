#!/bin/bash

set -e

prefix=

if [ ! -z $2 ] && [ $2 = "in_chroot" ]
then
    prefix="arch-chroot /mnt "
fi

install_command="${prefix}pacman -Syu --needed --noconfirm"

# install and configure some packages, services
# fonts
$install_command ttf-dejavu ttf-liberation noto-fonts-emoji ttf-hack adobe-source-han-sans-cn-fonts adobe-source-han-sans-tw-fonts adobe-source-han-serif-cn-fonts adobe-source-han-serif-tw-fonts adobe-source-han-sans-jp-fonts adobe-source-han-sans-kr-fonts

# audio
$install_command pulseaudio-alsa alsa-utils pulseaudio-bluetooth

# desktop environment
$install_command xorg-server

# usb 3g modem
$install_command modemmanager usb_modeswitch wvdial
${prefix}systemctl enable ModemManager

# browsers
$install_command chromium firefox-developer-edition torbrowser-launcher

# editors
$install_command emacs gvim

# programming packages
$install_command gdb cmake git go valgrind tk dia clang gcc python jdk-openjdk dotnet-sdk intellij-idea-community-edition pycharm-community-edition

# tools
$install_command reflector wimlib transmission-gtk keepassxc expect pacman-contrib gprename pdftk deja-dup curl kdiff3 lm_sensors dosfstools ntfs-3g p7zip unrar gparted wget youtube-dl cdrtools fuseiso efitools sbsigntools

# remote desktop
$install_command remmina libvncserver freerdp

# office and learning
$install_command libreoffice-fresh calibre kchmviewer goldendict kolourpaint thunderbird librecad gimp inkscape geogebra sweethome3d hexchat gnucash

# multimedia
$install_command obs-studio vlc kdenlive frei0r-plugins blender handbrake handbrake-cli audacity aegisub kid3 rhythmbox mkvtoolnix-gui pencil2d

# virtualbox
$install_command virtualbox virtualbox-guest-iso virtualbox-host-dkms
if [ ! -z $1 ]
then
    ${prefix}gpasswd -a $1 vboxusers
fi

# wireshark
$install_command wireshark-qt
if [ ! -z $1 ]
then
    ${prefix}gpasswd -a $1 wireshark
fi

# docker
$install_command docker
${prefix}systemctl enable docker
if [ ! -z $1 ]
then
    ${prefix}gpasswd -a $1 docker
fi

# games
$install_command kigo bovo gnuchess wesnoth steam steam-native-runtime discord

# enable bluetooth service
${prefix}systemctl enable bluetooth
