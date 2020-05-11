#!/bin/bash

set -e

# partition the disk
if [ $bootloader = 2 ]
then
    sgdisk -n 0:0:+1G -t 0:8309 -c 0:"cryptboot" /dev/$install_dev
fi
sgdisk -n 0:0:0 -t 0:8309 -c 0:"cryptlvm" /dev/$install_dev

case $bootloader in
    1) # systemd-boot
	# create the LUKS encrypted container
	dd if=/dev/zero of=/dev/${install_dev}${part}5 bs=1M count=1
	printf "$storagepass1" | cryptsetup luksFormat --type luks2 /dev/${install_dev}${part}5 -

	# open the container
	printf "$storagepass1" | cryptsetup open /dev/${install_dev}${part}5 cryptlvm -
	;;
    2) # GRUB
	dd if=/dev/zero of=/dev/${install_dev}${part}5 bs=1M count=1
	printf "$bootpass1" | cryptsetup luksFormat --type luks1 /dev/${install_dev}${part}5 -
	printf "$bootpass1" | cryptsetup open /dev/${install_dev}${part}5 cryptboot -
	
	# create the LUKS encrypted container
	dd if=/dev/zero of=/dev/${install_dev}${part}6 bs=1M count=1
	printf "$storagepass1" | cryptsetup luksFormat --type luks2 /dev/${install_dev}${part}6 -

	# open the container
	printf "$storagepass1" | cryptsetup open /dev/${install_dev}${part}6 cryptlvm -
	;;
esac

# create a physical volume on top of the opened LUKS container
pvcreate /dev/mapper/cryptlvm

# create the volume group named sys_vol_group
vgcreate sys_vol_group /dev/mapper/cryptlvm

# create all logical volumes on the volume group
lvcreate -L `expr 2 \* $size_of_ram`G sys_vol_group -n swap
lvcreate -l +100%FREE sys_vol_group -n root

# format the partitions
if [ $bootloader = 2 ]
then
    mkfs.ext4 /dev/mapper/cryptboot
fi
mkswap /dev/sys_vol_group/swap
swapon /dev/sys_vol_group/swap
mkfs.ext4 /dev/sys_vol_group/root

# mount the filesystems
mount /dev/sys_vol_group/root /mnt
case $bootloader in
    1) # systemd-boot
	mkdir /mnt/boot
	mount /dev/${install_dev}${part}2 /mnt/boot
	;;
    2) # GRUB
	mkdir /mnt/boot
	mount /dev/mapper/cryptboot /mnt/boot
	mkdir /mnt/boot/efi
	mount /dev/${install_dev}${part}2 /mnt/boot/efi
	;;
esac
