#!/bin/bash

set -eu

GOLDEN_IMAGE="${BUILD_BINARIESDIRECTORY}/golden_image.7z"
IMG_MOUNT_POINT="${BUILD_BINARIESDIRECTORY}/golden_image/rootfs"
# offset is sector size * sector start, can be read using `fdisk -l *.img`
IMG_MOUNT_OFFSET=4194304

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
	chroot "${BUILD_BINARIESDIRECTORY}/golden_image/rootfs" "$@"
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
	7z x -o"${BUILD_BINARIESDIRECTORY}/golden_image" "${GOLDEN_IMAGE}"
}

function check_image() {
	echo "Checking golden image..."
	( cd "${BUILD_BINARIESDIRECTORY}/golden_image" && shasum -a 256 -c sha256sum.sha )
}

function mount_rootfs() {
	echo "Mounting golden image..."
	mkdir -p "${IMG_MOUNT_POINT}"
	mount -o loop,offset=${IMG_MOUNT_OFFSET} "${BUILD_BINARIESDIRECTORY}/golden_image/"*.img "${IMG_MOUNT_POINT}"
}

function apply_changeset() {
	CHANGESET="${BUILD_SOURCESDIRECTORY}/$1"

	echo "Running pre apply hook..."
	! ( "${CHANGESET}/hooks/pre_apply_changeset.sh" )

	echo "Applying packages..."
	foreach "${CHANGESET}/packages/remove.list" chrootdo apt-get purge -y
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
	umount "${IMG_MOUNT_POINT}"
}



#######################################################################################
# workflow
#######################################################################################

if [ ! -f ${GOLDEN_IMAGE} ]; then
	download_image
fi

unzip_image
check_image
mount_rootfs
apply_changeset changeset_common
umount_rootfs

