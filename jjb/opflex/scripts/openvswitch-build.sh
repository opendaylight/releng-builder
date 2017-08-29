#!/bin/bash
# Build script for openvswitch

set -e
set -x

echo "---> scripts/openvswitch-build.sh"

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR"

./boot.sh
./configure --prefix="$ROOT" --enable-shared
make -j4
DESTDIR=`pwd`/$DESTDIR make install

if [[ ! $OPENVSWITCH_VERSION =~ noiro ]]; then
    mkdir -p $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openvswitch/*.h $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openflow $DESTDIR/$ROOT/include/openvswitch
    cp -t "$DESTDIR/$ROOT/include/openvswitch/" include/*.h
fi
find lib -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;

pushd $DESTDIR
tar -cvzf "openvswitch-$OPENVSWITCH_VERSION.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
