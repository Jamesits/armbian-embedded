#!/bin/bash

set -eu

GOLDEN_IMAGE="${BUILD_BINARIESDIRECTORY}/golden_image.7z"

if [ ! -f ${GOLDEN_IMAGE} ]; then
	echo "Downloading golden image..."
	wget "${GOLDEN_IMAGE_URL}" -O "${GOLDEN_IMAGE}"
fi

echo "Unzipping golden image..."
7z x -o"${BUILD_BINARIESDIRECTORY}/golden_image" "${GOLDEN_IMAGE}"
