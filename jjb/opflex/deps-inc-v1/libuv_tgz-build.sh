#!/bin/bash

set -e
set -x

if [[ $LIBUV_BUILD =~ v1 ]]; then
    version="1.7.5"
else
    version="1.8.0"
fi

./autogen.sh
ROOT=/tmp/opflex-prefix
./configure --prefix=$ROOT
mkdir install-root
DESTDIR=`pwd`/install-root make clean install
pushd install-root
tar -cvzf "libuv-$version.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
