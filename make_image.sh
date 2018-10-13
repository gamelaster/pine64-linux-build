#!/bin/bash

set -x 
set -e

IMAGE_NAME="$1"
TARBALL="$2"
MODEL="$3"

if [ -z "$IMAGE_NAME" ] || [ -z "$TARBALL" ] || [ -z "$MODEL" ]; then
  echo "Usage: $0 <image name> <tarball> <model>"
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
dd if=build/u-boot/u-boot-sunxi-with-spl-${MODEL}.bin of=${LOOP_DEVICE} bs=8k seek=1

echo "Installing kernel and other files"
mkdir -p ${TEMP_ROOT}/boot/dtbs/allwinner/
cp build/linux/arch/arm64/boot/dts/allwinner/sun50i-a64-pine64.dtb ${TEMP_ROOT}/boot/dtbs/allwinner/sun50i-a64-pine64.dtb
cp build/linux/arch/arm64/boot/dts/allwinner/sun50i-a64-pine64-plus.dtb ${TEMP_ROOT}/boot/dtbs/allwinner/sun50i-a64-pine64-plus.dtb
cp build/linux/arch/arm64/boot/dts/allwinner/sun50i-a64-pinebook.dtb ${TEMP_ROOT}/boot/dtbs/allwinner/sun50i-a64-pinebook.dtb
cp build/linux/arch/arm64/boot/dts/allwinner/sun50i-a64-sopine-baseboard.dtb ${TEMP_ROOT}/boot/dtbs/allwinner/sun50i-a64-sopine-baseboard.dtb
cp build/linux/arch/arm64/boot/Image ${TEMP_ROOT}/boot/Image
gzip -k ${TEMP_ROOT}/boot/Image
cp otherfiles/mkscr ${TEMP_ROOT}/boot/mkscr
cp otherfiles/boot.txt ${TEMP_ROOT}/boot/boot.txt
cp otherfiles/boot.scr ${TEMP_ROOT}/boot/boot.scr
cp build/u-boot/u-boot-sunxi-with-spl-${MODEL}.bin ${TEMP_ROOT}/boot/u-boot-sunxi-with-spl-${MODEL}.bin

echo "Unmounting rootfs"
umount $TEMP_ROOT
rm -rf $TEMP_ROOT

# Detach loop device
losetup -d $LOOP_DEVICE