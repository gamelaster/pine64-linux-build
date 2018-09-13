export RELEASE_NAME ?= $(shell date +%Y%m%d)

rootfs-$(RELEASE_NAME).tar.gz:
	./make_rootfs.sh rootfs-$(RELEASE_NAME) $@

archlinux-xfce-pine64-$(RELEASE_NAME).img: rootfs-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pine64.bin

archlinux-xfce-sopine-$(RELEASE_NAME).img: rootfs-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@
	./make_image.sh $@ $< u-boot-sunxi-with-spl-sopine.bin
	
archlinux-xfce-pinebook-$(RELEASE_NAME).img: rootfs-$(RELEASE_NAME).tar.gz
	./make_empty_image.sh $@
	./make_image.sh $@ $< u-boot-sunxi-with-spl-pinebook.bin
	
.PHONY: archlinux-xfce-pine64
archlinux-xfce-pine64: archlinux-xfce-pine64-$(RELEASE_NAME).img

.PHONY: archlinux-xfce-sopine
archlinux-xfce-sopine: archlinux-xfce-sopine-$(RELEASE_NAME).img

.PHONY: archlinux-xfce-pinebook
archlinux-xfce-pinebook: archlinux-xfce-pinebook-$(RELEASE_NAME).img
