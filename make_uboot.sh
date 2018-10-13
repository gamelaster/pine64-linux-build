#!/bin/bash

set -e

UBOOT_REPO=https://github.com/anarsoul/u-boot-pine64/
UBOOT_REPO_BRANCH=pinebook-wip-20181012
ATF_REPO=https://github.com/apritzel/arm-trusted-firmware/
ATF_REPO_BRANCH=allwinner
MODEL="$1"
BUILD="build"

export CROSS_COMPILE=aarch64-linux-gnu-

mkdir -p "$BUILD"
pushd "$BUILD"
if [ ! -d "arm-trusted-firmware" ] ; then
  git clone --depth 1 --branch $ATF_REPO_BRANCH $ATF_REPO arm-trusted-firmware
fi
if [ ! -d "u-boot" ] ; then
  git clone --depth 1 --branch $UBOOT_REPO_BRANCH $UBOOT_REPO u-boot
fi

pushd "arm-trusted-firmware"
make clean
make PLAT=sun50iw1p1 DEBUG=1 bl31
cp build/sun50iw1p1/debug/bl31.bin ../u-boot/
popd

pushd u-boot
make clean
make ${MODEL}_defconfig
make -j$(nproc)
dd if=spl/sunxi-spl.bin of=u-boot-sunxi-with-spl-${MODEL}.bin bs=1024
dd if=u-boot.itb of=u-boot-sunxi-with-spl-${MODEL}.bin bs=1024 seek=32 conv=notrunc

popd

popd