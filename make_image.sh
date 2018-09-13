#!/bin/bash

set -x 
set -e

IMAGE_NAME="$1"
TARBALL="$2"
BOOTLOADER="$3"

if [ -z "$IMAGE_NAME" ] || [ -z "$TARBALL" ] || [ -z "$BOOTLOADER" ]; then
	echo "Usage: $0 <image name> <tarball> <bootloader>"
	exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

echo "Attaching loop device"
LOOP_DEVICE=$(losetup -f)
losetup -P $LOOP_DEVICE $IMAGE_NAME

echo "Creating filesystems"
mkfs.vfat ${LOOP_DEVICE}p1
mkswap ${LOOP_DEVICE}p2
mkfs.ext4 ${LOOP_DEVICE}p3

TEMP_ROOT=$(mktemp -d)
mkdir -p $TEMP_ROOT
echo "Mounting rootfs"
mount ${LOOP_DEVICE}p3 $TEMP_ROOT

echo "Unpacking rootfs archive"
bsdtar -xpf "$TARBALL" -C "$TEMP_ROOT"

echo "Installing bootloader"
dd if=$TEMP_ROOT/boot/$BOOTLOADER of=${LOOP_DEVICE} bs=8k seek=1

echo "Unmounting rootfs"
umount $TEMP_ROOT
rm -rf $TEMP_ROOT

# Detach loop device
losetup -d $LOOP_DEVICE
