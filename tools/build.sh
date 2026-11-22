#!/bin/sh
set -e
cd "$(dirname "$0")/.."
mkdir -p build/tools
exec odin run tools/build.odin -file -out:build/tools/build -- "$@"
