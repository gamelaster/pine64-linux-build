#!/bin/bash

set -e
set -x

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

cleanup() {
	if [ -e "$DEST/proc/cmdline" ]; then
		umount "$DEST/proc"
	fi
	if [ -d "$DEST/sys/kernel" ]; then
		umount "$DEST/sys"
	fi
	umount "$DEST/dev" || true
	umount "$DEST/tmp" || true
}
trap cleanup EXIT

DEST=rootfs-20180912

mount -o bind /tmp "$DEST/tmp"
mount -o bind /dev "$DEST/dev"
chroot "$DEST" mount -t proc proc /proc
chroot "$DEST" mount -t sysfs sys /sys
#chroot "$DEST" mv /etc/resolv.conf /etc/resolv.conf.dist
cp /etc/resolv.conf $DEST/etc/resolv.conf
chroot "$DEST" $@
#chroot "$DEST" mv /etc/resolv.conf.dist /etc/resolv.conf
chroot "$DEST" umount /sys
chroot "$DEST" umount /proc
umount "$DEST/dev"
umount "$DEST/tmp"
