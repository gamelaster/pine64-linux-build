#!/bin/bash

set -e

LINUX_REPO=https://github.com/anarsoul/linux-2.6/
LINUX_REPO_BRANCH=sunxi64-4.18
BUILD="build"
MODEL="$1"

export CROSS_COMPILE=aarch64-linux-gnu-

mkdir -p "$BUILD"
pushd "$BUILD"
if [ ! -d "linux" ] ; then
  git clone --depth 1 --branch $LINUX_REPO_BRANCH $LINUX_REPO linux
fi
pushd linux
cp "../../configs/config_${MODEL}" .config
make ARCH=arm64 -j$(nproc) Image dtbs modules
make ARCH=arm64 INSTALL_MOD_PATH="output" modules_install
popd

popd