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

# Determine the version to download
if [[ $OPENVSWITCH_BUILD =~ v1 ]]; then
    openvswitch_version="noiro"
else
    openvswitch_version="2.6.0"
fi

if [[ $RAPIDJSON_BUILD =~ v1 ]]; then
    rapidjson_version="1.0.1"
else
    rapidjson_version="1.0.2"
fi

if [[ $LIBUV_BUILD =~ v1 ]]; then
    libuv_version="1.7.5"
else
    libuv_version="1.8.0"
fi

# Download the artifacts from nexus thirdparty
wget -nv ${NEXUS_URL}/service/local/repositories/thirdparty/content/openvswitch/openvswitch/${openvswitch_version}/openvswitch-${openvswitch_version}.tar.gz
wget -nv ${NEXUS_URL}/service/local/repositories/thirdparty/content/rapidjson/rapidjson/${rapidjson_version}/rapidjson-${rapidjson_version}.tar.gz
wget -nv ${NEXUS_URL}/service/local/repositories/thirdparty/content/libuv/libuv/${libuv_version}/libuv-${libuv_version}.tar.gz

tar -xz -C "$ROOT" --strip-components=2 -f libuv-${libuv_version}.tar.gz
tar -xz -C "$ROOT" --strip-components=2 -f rapidjson-${rapidjson_version}.tar.gz
tar -xz -C "$ROOT" --strip-components=2 -f openvswitch-${openvswitch_version}.tar.gz

export PATH="$ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$ROOT/lib"
export PKG_CONFIG_PATH="$ROOT/lib/pkgconfig"

# Move OpFlex artifacts to upload files directory
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"

# build libopflex
pushd libopflex
./autogen.sh
./configure --prefix="$ROOT" \
    --with-buildversion=$BUILD_NUMBER \
    CPPFLAGS="-isystem $ROOT/include" \
    CXXFLAGS="-Wall"
make -j8
if ! make check; then find . -name test-suite.log -exec cat {} \; && false; fi
make install
make dist
mv *.tar.gz "$UPLOAD_FILES_PATH"
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
mv *.tar.gz "$UPLOAD_FILES_PATH"
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
if ! make check; then find . -name test-suite.log -exec cat {} \; && false; fi
make dist
mv *.tar.gz "$UPLOAD_FILES_PATH"
popd
