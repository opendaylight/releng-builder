#!/bin/bash
# Build script for opflex

set -e
set -x

ROOT=/tmp/opflex-prefix

function cleanup {
    if [ -d "$ROOT" ]; then rm -rf "$ROOT"; fi
}

# create dependency root prefix
cleanup
mkdir -p "$ROOT"
trap cleanup EXIT

tar -xz -C "$ROOT" --strip-components=2 -f libuv.tgz
tar -xz -C "$ROOT" --strip-components=2 -f rapidjson.tgz
tar -xz -C "$ROOT" --strip-components=2 -f openvswitch.tgz

export PATH="$ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$ROOT/lib"
export PKG_CONFIG_PATH="$ROOT/lib/pkgconfig"

# build libopflex
pushd libopflex
./autogen.sh
./configure --prefix="$ROOT" \
    --with-buildversion=$BUILD_NUMBER \
    CPPFLAGS="-isystem $ROOT/include"
    CXXFLAGS="-Wall"
make -j8
make check || find . -name test-suite.log -exec cat {} \; && false
make install
make dist
popd

# build libmodelgbp
pushd genie
CLASSPATH=target/classes java org.opendaylight.opflex.genie.Genie
pushd target/libmodelgbp
bash autogen.sh
./configure --prefix="$ROOT"
make -j2
make install
make dist
popd
popd

# build agent-ovs
pushd agent-ovs
./autogen.sh
./configure --prefix="$ROOT" \
    --with-buildversion=$BUILD_NUMBER \
    CPPFLAGS="-isystem $ROOT/include" \
    CXXFLAGS="-Wall"
make -j8
make check || find . -name test-suite.log -exec cat {} \; && false
make dist
popd
