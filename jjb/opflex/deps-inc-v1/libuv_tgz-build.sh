#!/bin/bash

set -e
set -x

./autogen.sh
ROOT=/tmp/opflex-prefix
./configure --prefix=$ROOT
mkdir install-root
DESTDIR=`pwd`/install-root make clean install
pushd install-root
tar -czf libuv.tgz *
popd
