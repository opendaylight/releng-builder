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

# OVS headers get installed to weird and inconsistent locations.  Try
# to clean things up
mkdir -p $DESTDIR/$ROOT/include/openvswitch/openvswitch
mv $DESTDIR/$ROOT/include/openvswitch/*.h $DESTDIR/$ROOT/include/openvswitch/openvswitch
mv $DESTDIR/$ROOT/include/openflow $DESTDIR/$ROOT/include/openvswitch
cp -t "$DESTDIR/$ROOT/include/openvswitch/" include/*.h
find lib -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;

pushd $DESTDIR
tar -czf openvswitch.tgz *
popd

