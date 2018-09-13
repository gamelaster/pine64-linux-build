#!/bin/bash

set -e

BUILD="build"
OTHERDIR="otherfiles"
DEST="$1"
OUT_TARBALL="$2"
BUILD_ARCH=arm64

export LC_ALL=C

if [ -z "$DEST" ] || [ -z "$OUT_TARBALL" ]; then
	echo "Usage: $0 <destination-folder> <destination-tarball>"
	exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
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

ROOTFS="http://archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
TAR_OPTIONS=""

mkdir -p $BUILD
TARBALL="$BUILD/$(basename $ROOTFS)"

mkdir -p "$BUILD"
if [ ! -e "$TARBALL" ]; then
	echo "Downloading $DISTRO rootfs tarball ..."
	wget -O "$TARBALL" "$ROOTFS"
fi

# Extract with BSD tar
echo -n "Extracting ... "
set -x
bsdtar -xpf $TAR_OPTIONS "$TARBALL" -C "$DEST"
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

mv "$DEST/etc/resolv.conf" "$DEST/etc/resolv.conf.dist"
cp /etc/resolv.conf "$DEST/etc/resolv.conf"
sed -i 's|CheckSpace|#CheckSpace|' "$DEST/etc/pacman.conf"

cat >> "$DEST/etc/pacman.conf" <<EOF
[pine64-mainline]
SigLevel = Never
Server = https://github.com/anarsoul/PKGBUILDs/releases/download/mainline/
EOF

cat > "$DEST/second-phase" <<EOF
#!/bin/sh
pacman-key --init
pacman-key --populate archlinuxarm
killall -KILL gpg-agent
pacman -Sy --noconfirm
pacman -Rsn --noconfirm linux-aarch64
pacman -S --noconfirm --needed dosfstools curl xz iw rfkill netctl dialog wpa_supplicant alsa-utils \
	pv linux-pine64 linux-pine64-headers networkmanager dkms-rtl8723cs uboot-pine64-git

# Install XFCE
pacman -S --noconfirm xfce4 xorg-server xf86-input-libinput lxdm ttf-dejavu ttf-liberation firefox  \
      		pulseaudio nm-connection-editor network-manager-applet \
      		xfce4-pulseaudio-plugin \
      		pulseaudio-alsa pavucontrol
systemctl enable lxdm
systemctl enable NetworkManager
usermod -a -G network,video,audio,optical,storage,input,scanner,games,lp alarm

sed -i 's|^#en_US.UTF-8|en_US.UTF-8|' /etc/locale.gen
cd /usr/share/i18n/charmaps
# locale-gen can't spawn gzip when running under qemu-user, so ungzip charmap before running it
# and then gzip it back
gzip -d UTF-8.gz
locale-gen
gzip UTF-8
yes | pacman -Scc
EOF
chmod +x "$DEST/second-phase"
do_chroot /second-phase
rm $DEST/second-phase

# Final touches
rm "$DEST/usr/bin/qemu-aarch64-static"
rm "$DEST/usr/bin/qemu-arm-static"
mv "$DEST/etc/resolv.conf.dist" "$DEST/etc/resolv.conf"

cp $OTHERDIR/asound.state $DEST/var/lib/alsa
cp $OTHERDIR/pine64_first_boot.sh $DEST/usr/local/sbin/
cp $OTHERDIR/resize_rootfs.sh $DEST/usr/local/sbin/
cp $OTHERDIR/pine64-first-boot.service $DEST/etc/systemd/system/
cp $OTHERDIR/modesetting.conf $DEST/etc/X11/xorg.conf.d/
cp $OTHERDIR/sysrq.conf $DEST/etc/sysctl.d/

echo "Installed rootfs to $DEST"

# Create tarball with BSD tar
echo -n "Creating tarball ... "
pushd .
cd $DEST && bsdtar -czpf ../$OUT_TARBALL .
popd
rm -rf $DEST

set -x
echo "Done"
