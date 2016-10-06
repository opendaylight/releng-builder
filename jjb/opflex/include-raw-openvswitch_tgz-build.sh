#!/bin/bash
# Build script for openvswitch

set -e
set -x

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR"

./boot.sh
./configure --prefix="$ROOT" --enable-shared
make -j4
DESTDIR=`pwd`/$DESTDIR make install

pushd $DESTDIR
tar -czf openvswitch.tgz *
