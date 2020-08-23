#!/bin/bash

set -e

parent_dir=$(cd $(dirname $0)/..; pwd)
partnum=1

arch-chroot /mnt pacman -Syu --needed --noconfirm efitools

case $bootloader in
    1) # systemd-boot
        cp $parent_dir/data/preloader-signed/{PreLoader,HashTool}.efi /mnt/boot/EFI/systemd
        cp /mnt/boot/EFI/systemd/systemd-bootx64.efi /mnt/boot/EFI/systemd/loader.efi
	arch-chroot /mnt cp /usr/share/efitools/efi/KeyTool.efi /boot/EFI/systemd/
	arch-chroot /mnt efibootmgr --verbose --disk /dev/$install_dev --part $partnum --create --label "KeyTool" --loader /EFI/systemd/KeyTool.efi
	arch-chroot /mnt efibootmgr --verbose --disk /dev/$install_dev --part $partnum --create --label "Arch Linux SB" --loader /EFI/systemd/PreLoader.efi
	;;
    2) # GRUB (encrypted boot)
	;&
    3) # GRUB (non-encrypted boot)
        cp $parent_dir/data/preloader-signed/{PreLoader,HashTool}.efi /mnt/boot/efi/EFI/archlinux
        cp /mnt/boot/efi/EFI/archlinux/grubx64.efi /mnt/boot/efi/EFI/archlinux/loader.efi
	arch-chroot /mnt cp /usr/share/efitools/efi/KeyTool.efi /boot/efi/EFI/archlinux/
	arch-chroot /mnt efibootmgr --verbose --disk /dev/$install_dev --part $partnum --create --label "KeyTool" --loader /EFI/archlinux/KeyTool.efi
	arch-chroot /mnt efibootmgr --verbose --disk /dev/$install_dev --part $partnum --create --label "Arch Linux SB" --loader /EFI/archlinux/PreLoader.efi
	;;
esac


