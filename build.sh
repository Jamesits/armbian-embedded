#!/bin/bash
set -Eeuo pipefail
set -x

cd "$( dirname "${BASH_SOURCE[0]}" )"

pushd armbian-build
./compile.sh consoleserver-nanopir2s USERPATCHES_PATH="../userpatches/"
