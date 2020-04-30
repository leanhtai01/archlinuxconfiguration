#!/bin/bash

set -e

pacman -Syu --needed --noconfirm virt-manager qemu vde2 ebtables dnsmasq bridge-utils openbsd-netcat virt-viewer dmidecode
systemctl enable libvirtd
systemctl start libvirtd

cp /etc/libvirt/libvirtd.conf $original_config_files_path
printf "libvirtd.conf: /etc/libvirt/libvirtd.conf\n" >> $original_config_files_path/original_path.txt
sed -i "/^#unix_sock_group = \"libvirt\"$/s/^#//" /etc/libvirt/libvirtd.conf
sed -i "/^#unix_sock_rw_perms = \"0770\"$/s/^#//" /etc/libvirt/libvirtd.conf
gpasswd -a leanhtai01 libvirt