#!/bin/bash

set -e

BUILD="build"
OTHERDIR="otherfiles"
DEST="$1"
OUT_TARBALL="$2"
DISTRO="$3"
BUILD_ARCH=arm64

export LC_ALL=C

if [ -z "$DEST" ] || [ -z "$OUT_TARBALL" ] || [ -z "$DISTRO" ]; then
  echo "Usage: $0 <destination-folder> <destination-tarball> <distro>"
  exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
  echo "This script requires root."
  exit 1
fi

if [ ! -f "./configs/multistrap_$DISTRO.conf" ]; then
    echo "Multi strap config \"multistrap_$DISTRO.conf\" not found!"
    exit 1
fi

DEST=$(readlink -f "$DEST")

if [ ! -d "$DEST" ]; then
  mkdir -p $DEST
fi

if [ "$(ls -A -Ilost+found $DEST)" ]; then
  echo "Destination $DEST is not empty. Aborting."
  exit 1
fi

TEMP=$(mktemp -d)
cleanup() {
  if [ -e "$DEST/proc/cmdline" ]; then
    umount "$DEST/proc"
  fi
  if [ -d "$DEST/sys/kernel" ]; then
    umount "$DEST/sys"
  fi
  umount "$DEST/dev" || true
  umount "$DEST/tmp" || true
  if [ -d "$TEMP" ]; then
    rm -rf "$TEMP"
  fi
}
trap cleanup EXIT

# Extract with BSD tar
echo -n "Creating rootfs ... "
set -x
multistrap -a arm64 -d $DEST -f "./configs/multistrap_$DISTRO.conf"
echo "OK"

# Add qemu emulation.
cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin"
cp /usr/bin/qemu-arm-static "$DEST/usr/bin"

do_chroot() {
  cmd="$@"
  mount -o bind /tmp "$DEST/tmp"
  mount -o bind /dev "$DEST/dev"
  chroot "$DEST" mount -t proc proc /proc
  chroot "$DEST" mount -t sysfs sys /sys
  chroot "$DEST" $cmd
  chroot "$DEST" umount /sys
  chroot "$DEST" umount /proc
  umount "$DEST/dev"
  umount "$DEST/tmp"
}

cp /etc/resolv.conf "$DEST/etc/resolv.conf"

#cat > "$DEST/usr/sbin/policy-rc.d" <<EOF
##!/bin/sh
#exit 101
#EOF
#chmod a+x "$DEST/usr/sbin/policy-rc.d"

cat > "$DEST/second-phase" <<EOF
#!/bin/sh
set -ex
locale-gen en_US.UTF-8
echo "root:toor" | chpasswd
apt-get -y update
apt-get clean
EOF
chmod +x "$DEST/second-phase"
do_chroot /second-phase
rm $DEST/second-phase

cat > "$DEST/etc/network/interfaces.d/eth0" <<EOF
allow-hotplug eth0
iface eth0 inet dhcp
EOF

cat > "$DEST/etc/hostname" <<EOF
pine64
EOF

cat > "$DEST/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 pine46
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

mkdir "$DEST/lib/modules"
# Install Kernel modules
make -C ./build/linux/ ARCH=arm64 modules_install INSTALL_MOD_PATH="$DEST"
# Install Kernel firmware
make -C ./build/linux/ ARCH=arm64 firmware_install INSTALL_MOD_PATH="$DEST"
# Install Kernel headers
make -C ./build/linux/ ARCH=arm64 headers_install INSTALL_HDR_PATH="$DEST/usr"


# Final touches
rm "$DEST/usr/bin/qemu-aarch64-static"
rm "$DEST/usr/bin/qemu-arm-static"
rm "$DEST/etc/resolv.conf"
#rm -f "$DEST/usr/sbin/policy-rc.d"

#cp $OTHERDIR/asound.state $DEST/var/lib/alsa
cp $OTHERDIR/pine64_first_boot.sh $DEST/usr/bin/
cp $OTHERDIR/resize_rootfs.sh $DEST/usr/bin/
cp $OTHERDIR/pine64-first-boot.service $DEST/etc/systemd/system/
#cp $OTHERDIR/modesetting.conf $DEST/etc/X11/xorg.conf.d/
#cp $OTHERDIR/sysrq.conf $DEST/etc/sysctl.d/

echo "Installed rootfs to $DEST"

# Create tarball with BSD tar
echo -n "Creating tarball ... "
pushd .
cd $DEST && bsdtar -czpf ../$OUT_TARBALL .
popd
rm -rf $DEST

set -x
echo "Done"