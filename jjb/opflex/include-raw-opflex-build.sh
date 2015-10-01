#!/bin/bash
# Build script for opflex

set -e
set -x

# create dependency root prefix
ROOT=/opt/jenkins/prefix
if [ -d "$ROOT" ]; then rm -rf "$ROOT"; fi
mkdir -p "$ROOT"

# Temporary workaround to broken copy-artifacts
curl -O https://jenkins.opendaylight.org/sandbox/job/opflex-libuv_tgz-beryllium/jdk=openjdk7,nodes=dynamic_verify/lastSuccessfulBuild/artifact/install-root/libuv.tgz
curl -O https://jenkins.opendaylight.org/sandbox/job/opflex-rapidjson_tgz-beryllium/jdk=openjdk7,nodes=dynamic_verify/lastSuccessfulBuild/artifact/install-root/rapidjson.tgz
curl -O https://jenkins.opendaylight.org/sandbox/job/opflex-openvswitch_tgz-beryllium/jdk=openjdk7,nodes=dynamic_verify/lastSuccessfulBuild/artifact/install-root/openvswitch.tgz

tar -xz -C "$ROOT" --strip-components=3 -f libuv.tgz
tar -xz -C "$ROOT" --strip-components=3 -f rapidjson.tgz
tar -xz -C "$ROOT" --strip-components=3 -f openvswitch.tgz

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
make check
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
make check
make dist
popd
