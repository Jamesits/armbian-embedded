#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

apt-get install -y p7zip-full build-essential squashfs-tools zerofree u-boot-tools
