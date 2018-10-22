#!/bin/bash

set -eu

GOLDEN_IMAGE="${BUILD_BINARIESDIRECTORY}/golden_image.7z"
IMG_MOUNT_POINT="${BUILD_BINARIESDIRECTORY}/golden_image/rootfs"
# offset is sector size * sector start, can be read using `fdisk -l *.img`
IMG_MOUNT_OFFSET=4194304
BUILD_SOURCESDIRECTORY="${BUILD_SOURCESDIRECTORY}/src"

export LANGUAGE="C.UTF-8"
export LC_ALL="C.UTF-8"
export LC_MESSAGES="C.UTF-8"
export LANG="C.UTF-8"


#######################################################################################
# helpers
#######################################################################################

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 
	exit 1
fi

if [[ "$@" == "--crossbuild" ]]
then
	echo "Executing a crossbuild."
	CROSSBUILD=1
else
	CROSSBUILD=0
fi

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

function print_stage() {
	echo -e "${RED}${@}${NC}"
}

function print_info() {
        echo -e "${YELLOW}${@}${NC}"

}

function foreach() {
	FILE=$1
	COMMAND="${@:2}"
	while read -u 10 p; do
		$COMMAND "$p";
	done 10<"$1"
}

function chrootdo() {
	print_info "Running in chroot: $@"
	chroot "${IMG_MOUNT_POINT}" "$@"
}


function bindmount() {
	SRC=$1
	mount --bind "${SRC}" "${IMG_MOUNT_POINT}/${SRC}"
}

function bindumount() {
	SRC=$1
	umount "${IMG_MOUNT_POINT}/${SRC}"
}

function apt-compat() {
	if [ "$CROSSBUILD" -eq "1" ]; then
		apt-get -o Dir="${IMG_MOUNT_POINT}" -o Debug::NoLocking=1 "$@"
	else
		chrootdo apt-get "$@"
	fi
}

function systemctl-mask() {
	ln -sf /dev/null "$1/etc/systemd/system/$2"
}


#######################################################################################
# steps
#######################################################################################

function reset_build_dirs() {
	rm -rf --one-file-system "${BUILD_ARTIFACTSTAGINGDIRECTORY}/*"
	rm -rf --one-file-system "${BUILD_BINARIESDIRECTORY}/*"
}

function download_image() {
	print_stage "Downloading golden image..."
	wget "${GOLDEN_IMAGE_URL}" -O "${GOLDEN_IMAGE}"
}

function unzip_image() {
	print_stage "Unzipping golden image..."
	7z x -y -o"${BUILD_BINARIESDIRECTORY}/golden_image" "${GOLDEN_IMAGE}"
}

function check_image() {
	print_stage "Checking golden image..."
	( cd "${BUILD_BINARIESDIRECTORY}/golden_image" && shasum -a 256 -c sha256sum.sha )
}

function mount_rootfs() {
	print_stage "Mounting golden image..."
	mkdir -p "${IMG_MOUNT_POINT}"
	mount -o loop,offset=${IMG_MOUNT_OFFSET} "${BUILD_BINARIESDIRECTORY}/golden_image/"*.img "${IMG_MOUNT_POINT}"
}

function mount_sysfs() {
	print_stage "Mounting essential filesystems..."
	bindmount /etc/resolv.conf
	bindmount /dev
	bindmount /tmp
	bindmount /proc
	bindmount /run
}

function chroot_shell() {
	print_stage "Invoking a shell inside new root..."
	chrootdo
}

function apply_changeset() {
	print_stage "Applying changeset $1..."
	CHANGESET="${BUILD_SOURCESDIRECTORY}/$1"

	print_info "Running pre apply hook..."
	! ( "${CHANGESET}/hooks/pre_apply_changeset.sh" )

	print_info "Applying packages..."
	set +e
	foreach "${CHANGESET}/packages/remove.list" apt-compat purge -y
	set -e
	apt-compat autoremove --purge -y
	apt-compat update -y
	apt-compat full-upgrade -y
	foreach "${CHANGESET}/packages/install.list" apt-compat install -y
	apt-compat autoremove --purge -y
	apt-compat clean -y
	rm -rf "${IMG_MOUNT_POINT}/var/lib/apt/lists/"*

	print_info "Applying rootfs..."
	if [ -d "${CHANGESET}/rootfs" ]; then
		cp -rfvT "${CHANGESET}/rootfs/" "${IMG_MOUNT_POINT}/"
	fi

	print_info "Masking systemd units..."
	foreach "${CHANGESET}/systemd/mask.list" systemctl-mask "${IMG_MOUNT_POINT}"

	print_info "Running post apply hook..."
	! ( "${CHANGESET}/hooks/post_apply_changeset.sh" )

	print_info "Changeset $1 applied successfully."
}

function generate_boot_cfg() {
	print_stage "Generating essential boot config..."
	print_info "Generating u-boot script..."
	mkimage -C none -A arm -T script -d "${IMG_MOUNT_POINT}/boot/boot.cmd" "${IMG_MOUNT_POINT}/boot/boot.scr"
	print_info "Generating initramfs..."
	chrootdo update-initramfs -u -t -v -b /boot
	print_info "Generating uInitrd..."
	for file in "${IMG_MOUNT_POINT}/boot/"initrd.img-*; do
		mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${file}" "${IMG_MOUNT_POINT}/boot/uInitrd${$(basename ${file})#initrd.img}"
	done
}

function umount_rootfs() {
	print_stage "Unmounting rootfs..."
	umount "${IMG_MOUNT_POINT}"
}

function umount_sysfs() {
	print_stage "Unmounting essential system filesystems..."
	bindumount /etc/resolv.conf
	bindumount /dev
	bindumount /tmp
	bindumount /proc
	bindumount /run
}

function generate_readonly_image() {
	print_stage "Generating a readonly image..."
	
	NEWIMGROOT="${BUILD_ARTIFACTSTAGINGDIRECTORY}/imgroot"
	NEWIMG="${BUILD_ARTIFACTSTAGINGDIRECTORY}/armbian-embedded.img"
	NEWIMG_MOUNT_POINT="${BUILD_ARTIFACTSTAGINGDIRECTORY}/rootfs"
	PATHPREFIX="system"
	SQUASHFS_NAME="system.squashfs"

	print_info "Making the new root..."
	rm -rf "${NEWIMGROOT}"
	mkdir -p "${NEWIMGROOT}/${PATHPREFIX}"
	cp -rv "${IMG_MOUNT_POINT}/boot" "${NEWIMGROOT}"
	mksquashfs "${IMG_MOUNT_POINT}" "${NEWIMGROOT}/${PATHPREFIX}/${SQUASHFS_NAME}" -comp xz -Xbcj arm -info
	
	print_info "Generating system image..."
	cp -r "${BUILD_BINARIESDIRECTORY}/golden_image/"*.img ${NEWIMG}
	mkdir -p "${NEWIMG_MOUNT_POINT}"
	mount -o loop,offset=${IMG_MOUNT_OFFSET} "${NEWIMG}" "${NEWIMG_MOUNT_POINT}"
	rm -rf --one-file-system "${NEWIMG_MOUNT_POINT}"/*
	mv "${NEWIMGROOT}"/* "${NEWIMG_MOUNT_POINT}"
	umount "${NEWIMG_MOUNT_POINT}"

	print_info "Optimizating system image..."
	LOOPDEV=$(losetup --show -o "${IMG_MOUNT_OFFSET}" -f "${NEWIMG}")
	# e2fsck will return 1 if it has altered the filesysstem
	# which is likely to happen
	! e2fsck -fy -E discard "${LOOPDEV}"
	zerofree -v "${LOOPDEV}"
	losetup -d "${LOOPDEV}"

	print_info "Compressing system image..."
	# xz might fail if it cannot set the user and group
	xz --compress --force --format=xz --check=sha256 -1 --threads=0 --verbose "${NEWIMG}"

	print_info "Cleaning up..."
	rm -rf "${NEWIMGROOT}"
	rm -rf "${NEWIMG_MOUNT_POINT}"
}

#######################################################################################
# workflow
#######################################################################################

if [ ! -f ${GOLDEN_IMAGE} ]; then
	download_image
fi

! umount_sysfs
! umount_rootfs
reset_build_dirs
unzip_image
check_image
mount_rootfs
mount_sysfs

# for debugging only
#chroot_shell

apply_changeset changeset_common
generate_boot_cfg
umount_sysfs
generate_readonly_image
umount_rootfs

