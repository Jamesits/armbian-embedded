#!/bin/bash

set -eu

GOLDEN_IMAGE="${BUILD_BINARIESDIRECTORY}/golden_image.7z"
IMG_MOUNT_POINT="${BUILD_BINARIESDIRECTORY}/golden_image/rootfs"
# offset is sector size * sector start, can be read using `fdisk -l *.img`
IMG_MOUNT_OFFSET=4194304

#######################################################################################
# helpers
#######################################################################################


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

#######################################################################################
# workflow
#######################################################################################

if [ ! -f ${GOLDEN_IMAGE} ]; then
	download_image
fi

unzip_image
check_image
mount_rootfs

