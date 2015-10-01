#!/bin/bash
# Build script for openvswitch

set -e
set -x

ROOT=/opt/jenkins/prefix
DESTDIR=install-root

mkdir -p "$DESTDIR"

./boot.sh
mkdir -p /opt/jenkins/prefix
./configure --prefix=$ROOT --enable-shared
make -j8
DESTDIR=`pwd`/$DESTDIR make install
find lib ofproto -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;

pushd $DESTDIR
tar -czf openvswitch.tgz *
