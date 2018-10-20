#!/bin/bash
# compatible with Azure DevOps agent

set -eu

export GOLDEN_IMAGE_URL="http://v-fileswebhost.corp.nekomimiswitch.com/public/armbian/dl/orangepione/archive/Armbian_5.59_Orangepione_Ubuntu_xenial_default_3.4.113_desktop.7z"

export AGENT_BUILDDIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
export BUILD_ARTIFACTSTAGINGDIRECTORY=${AGENT_BUILDDIRECTORY}/artifacts
export BUILD_BINARIESDIRECTORY=${AGENT_BUILDDIRECTORY}/build
export BUILD_SOURCESDIRECTORY=${AGENT_BUILDDIRECTORY}/src
export SYSTEM_DEFAULTWORKINGDIRECTORY=${BUILD_SOURCESDIRECTORY}

mkdir -p $BUILD_ARTIFACTSTAGINGDIRECTORY
mkdir -p $BUILD_BINARIESDIRECTORY
mkdir -p $BUILD_SOURCESDIRECTORY

cd ${SYSTEM_DEFAULTWORKINGDIRECTORY}
. build.sh

