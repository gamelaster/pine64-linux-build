# pine64-linux-build
Linux build scripts for Pine64. Please note, that this scripts are unfinished, but they works! I store it here for now until I will finish the new scripts.

# Installation

Example: SOPine
```bash
./make_empty_image.sh debian_image.img
./make_uboot.sh sopine_baseboard
./make_kernel.sh sopine_baseboard
./make_rootfs.sh rootfs debian_stretch_rootfs.tar stretch
./make_image.sh debian_image.img debian_stretch_rootfs.tar sopine_baseboard
```
