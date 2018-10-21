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


function foreach() {
	FILE=$1
	COMMAND="${@:2}"
	while read -u 10 p; do
		$COMMAND "$p";
	done 10<"$1"
}

function chrootdo() {
	echo "Running in chroot: $@"
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
	echo "Downloading golden image..."
	wget "${GOLDEN_IMAGE_URL}" -O "${GOLDEN_IMAGE}"
}

function unzip_image() {
	echo "Unzipping golden image..."
	7z x -y -o"${BUILD_BINARIESDIRECTORY}/golden_image" "${GOLDEN_IMAGE}"
}

function check_image() {
	echo "Checking golden image..."
	( cd "${BUILD_BINARIESDIRECTORY}/golden_image" && shasum -a 256 -c sha256sum.sha )
}

function mount_rootfs() {
	echo "Mounting golden image..."
	mkdir -p "${IMG_MOUNT_POINT}"
	! umount_rootfs
	mount -o loop,offset=${IMG_MOUNT_OFFSET} "${BUILD_BINARIESDIRECTORY}/golden_image/"*.img "${IMG_MOUNT_POINT}"
	bindmount /etc/resolv.conf
	bindmount /dev
	bindmount /tmp
	bindmount /proc
	bindmount /run
}

function chroot_shell() {
	chrootdo
}

function apply_changeset() {
	CHANGESET="${BUILD_SOURCESDIRECTORY}/$1"

	echo "Running pre apply hook..."
	! ( "${CHANGESET}/hooks/pre_apply_changeset.sh" )

	echo "Applying packages..."
	foreach "${CHANGESET}/packages/remove.list" chrootdo apt-get purge -y
	chrootdo apt-get autoremove --purge -y
	chrootdo apt-get update -y
	chrootdo apt-get full-upgrade -y
	foreach "${CHANGESET}/packages/install.list" chrootdo apt-get install -y
	chrootdo rm -rf /var/lib/apt/lists
	chrootdo mkdir -p /var/lib/apt/lists

	echo "Applying rootfs..."
	if [ -d "${CHANGESET}/rootfs" ]; then
		cp -rfv "${CHANGESET}/rootfs" "${IMG_MOUNT_POINT}"
	fi

	echo "Running post apply hook..."
	! ( "${CHANGESET}/hooks/post_apply_changeset.sh" )

}

function umount_rootfs() {
	echo "Unmounting rootfs..."
	bindumount /etc/resolv.conf
	bindumount /dev
	bindumount /tmp
	bindumount /proc
	bindumount /run
	umount "${IMG_MOUNT_POINT}"
}

function generate_readonly_image() {
	echo "Generating a readonly image..."
	IMGROOT="${BUILD_ARTIFACTSTAGINGDIRECTORY}/imgroot"
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
# mount_rootfs
# chroot_shell
# apply_changeset changeset_common
generate_readonly_image
# umount_rootfs

