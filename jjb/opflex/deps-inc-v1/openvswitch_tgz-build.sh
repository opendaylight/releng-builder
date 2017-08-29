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
find lib ofproto -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;

pushd $DESTDIR
tar -cvzf "openvswitch-$version.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
