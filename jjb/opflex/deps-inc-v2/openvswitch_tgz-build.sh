#!/bin/bash
# Build script for openvswitch

set -e
set -x

if [[ $OPENVSWITCH_BUILD =~ v1 ]]; then
    version="noiro"
else
    version="2.6.0"
fi

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
tar -cvzf "openvswitch-$version.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
