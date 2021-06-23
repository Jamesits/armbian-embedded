#!/bin/bash
set -Eeuo pipefail
set -x

cd "$( dirname "${BASH_SOURCE[0]}" )"

pushd armbian-build
rm -f userpatches || true
ln -s ../userpatches userpatches
./compile.sh consoleserver-nanopir2s
