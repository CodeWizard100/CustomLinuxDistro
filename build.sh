#!/bin/bash

# Define variables with correct syntax
arch=${1:-amd64}
mirror=${2:-"http://archive.ubuntu.com/ubuntu/"}
release=${3:-xenial}

# Install necessary packages
sudo apt-get update
sudo apt-get install -y debootstrap squashfs-tools xorriso syslinux isolinux genisoimage

# Create necessary directories
mkdir -p image/isolinux
mkdir -p chroot

# Run debootstrap
sudo debootstrap --arch=${arch} ${release} chroot ${mirror}

# Copy sources.list
sudo cp -v sources.${release}.list chroot/etc/apt/sources.list

# Mount filesystem to chroot
sudo mount --rbind /sys chroot/sys
sudo mount --rbind /dev chroot/dev
sudo mount -t proc none chroot/proc

# Run chroot commands
sudo chroot chroot <<EOF
# Linking /sbin/initctl to /bin/true
ln -s /bin/true /sbin/initctl

# Upgrading the packages
apt-get -y upgrade

# Installing core packages
apt-get -qq -y --purge install ubuntu-standard casper lupin-casper laptop-detect os-prober linux-generic

# Installing base packages
apt-get -qq -y install xorg xinit sddm

# Installing LXQt components
apt-get -qq -y install lxqt openbox

# Cleaning up the ChRoot environment
rm /sbin/initctl
apt-get -qq clean
rm -rf /tmp/*
dpkg-divert --rename --remove /sbin/initctl
exit
EOF

# Copy required files
sudo tar xf image-amd64.tar.lzma -C image/
sudo cp --verbose -rf chroot/boot/vmlinuz-* image/casper/vmlinuz
sudo cp --verbose -rf chroot/boot/initrd.img-* image/casper/initrd.lz

# Create manifest
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop

REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE; do
    sudo sed -i "/${i}/d" image/casper/filesystem.manifest-desktop
done

# Copy isolinux.bin and other necessary files
sudo cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
sudo cp /usr/lib/syslinux/modules/bios/* image/isolinux/

# Create a basic isolinux.cfg file
cat <<EOF | sudo tee image/isolinux/isolinux.cfg
DEFAULT linux
LABEL linux
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd.lz boot=casper quiet splash ---
EOF

# Compress the filesystem
sudo mksquashfs chroot image/casper/filesystem.squashfs -noappend -no-progress
ls -lh image/casper/filesystem.squashfs

# Create ISO image
IMAGE_NAME=${IMAGE_NAME:-"CUSTOM ${release} $(date -u +%Y%m%d) - ${arch}"}
ISOFILE="custom-ubuntu.iso"

# Generate the ISO
sudo genisoimage -r -V "$IMAGE_NAME" -cache-inodes -J -l \
    -allow-limited-size -udf \
    -b isolinux/isolinux.bin -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -p "${DEBFULLNAME:-$USER} <${DEBMAIL:-on host $(hostname --fqdn)}>" \
    -A "$IMAGE_NAME" \
    -o $ISOFILE image/

# Check ISO size
ls -lh $ISOFILE
