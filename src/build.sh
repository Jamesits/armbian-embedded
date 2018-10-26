#!/bin/bash

set -eu
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

. ${DIR}/helper.sh

#######################################################################################
# workflow
#######################################################################################

if [ ! -f "${BUILD_BINARIESDIRECTORY}/download_finished" ]; then
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

before_apply_changeset
apply_changeset changeset_common
after_apply_changeset
generate_boot_cfg
umount_sysfs
generate_readonly_image
umount_rootfs

