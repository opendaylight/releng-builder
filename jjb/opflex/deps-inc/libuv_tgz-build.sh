#!/bin/bash

set -e
set -x

if [[ $LIBUV_BUILD =~ v1 ]]; then
    refs="refs/tags/v1.7.5"
else
    refs="refs/tags/v1.8.0"
fi

git clone https://github.com/libuv/libuv.git
cd libuv || exit 1
git checkout "$refs"

./autogen.sh
ROOT=/tmp/opflex-prefix
./configure --prefix=$ROOT
mkdir install-root
DESTDIR=`pwd`/install-root make clean install
pushd install-root
tar -czf libuv.tgz *
mv libuv.tgz "$WORKSPACE"
popd
