#!/bin/bash

set -eu

GOLDEN_IMAGE="${BUILD_BINARIESDIRECTORY}/golden_image.7z"
IMG_MOUNT_POINT="${BUILD_BINARIESDIRECTORY}/golden_image/rootfs"
# offset is sector size * sector start, can be read using `fdisk -l *.img`
IMG_MOUNT_OFFSET=4194304

export LANGUAGE="C.UTF-8"
export LC_ALL="C.UTF-8"
export LC_MESSAGES="C.UTF-8"
export LANG="C.UTF-8"


#######################################################################################
# helpers
#######################################################################################

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

function print_stage() {
	printf "${RED}${@}${NC}\n"
}

function print_info() {
        printf "${YELLOW}${@}${NC}\n"

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
	chroot "${BUILD_BINARIESDIRECTORY}/golden_image/rootfs" "$@"
}


function bindmount() {
	SRC=$1
	mount --bind "${SRC}" "${BUILD_BINARIESDIRECTORY}/golden_image/rootfs/${SRC}"
}



function bindumount() {
	SRC=$1
	umount "${BUILD_BINARIESDIRECTORY}/golden_image/rootfs/${SRC}"
}



#######################################################################################
# steps
#######################################################################################

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
	foreach "${CHANGESET}/packages/remove.list" chrootdo apt-get purge -y
	set -e
	chrootdo apt-get autoremove --purge -y
	chrootdo apt-get update -y
	chrootdo apt-get full-upgrade -y
	foreach "${CHANGESET}/packages/install.list" chrootdo apt-get install -y
	chrootdo rm -rf /var/lib/apt/lists
	chrootdo mkdir -p /var/lib/apt/lists

	print_info "Applying rootfs..."
	if [ -d "${CHANGESET}/rootfs" ]; then
		cp -rfv "${CHANGESET}/rootfs" "${IMG_MOUNT_POINT}"
	fi

	print_info "Running post apply hook..."
	! ( "${CHANGESET}/hooks/post_apply_changeset.sh" )

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
	IMGROOT="${BUILD_ARTIFACTSTAGINGDIRECTORY}/imgroot"
	rm -rf "${IMGROOT}"
	mkdir -p "${IMGROOT}"
	mv "${IMG_MOUNT_POINT}/boot" "${IMGROOT}"
	mksquashfs "${IMG_MOUNT_POINT}" "${IMGROOT}/system.squashfs" -comp xz -Xbcj arm -info
}

#######################################################################################
# workflow
#######################################################################################

if [ ! -f ${GOLDEN_IMAGE} ]; then
	download_image
fi

# unzip_image
# check_image
! umount_sysfs
! umount_rootfs
mount_rootfs
mount_sysfs
# chroot_shell
apply_changeset changeset_common
umount_sysfs
generate_readonly_image
# umount_rootfs

