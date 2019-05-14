#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> scripts/opflex-build.sh"

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

# Download the artifacts from nexus thirdparty
wget -nv "${NEXUS_URL}/service/local/repositories/thirdparty/content/openvswitch/openvswitch/${OPENVSWITCH_VERSION}/openvswitch-${OPENVSWITCH_VERSION}.tar.gz"
wget -nv "${NEXUS_URL}/service/local/repositories/thirdparty/content/rapidjson/rapidjson/${RAPIDJSON_VERSION}/rapidjson-${RAPIDJSON_VERSION}.tar.gz"
wget -nv "${NEXUS_URL}/service/local/repositories/thirdparty/content/libuv/libuv/${LIBUV_VERSION}/libuv-${LIBUV_VERSION}.tar.gz"

tar -xz -C "$ROOT" --strip-components=2 -f "libuv-${LIBUV_VERSION}.tar.gz"
tar -xz -C "$ROOT" --strip-components=2 -f "rapidjson-${RAPIDJSON_VERSION}.tar.gz"
tar -xz -C "$ROOT" --strip-components=2 -f "openvswitch-${OPENVSWITCH_VERSION}.tar.gz"

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
    --with-buildversion="$BUILD_NUMBER" \
    CPPFLAGS="-isystem $ROOT/include" \
    CXXFLAGS="-Wall"
make -j4
if ! make check; then find . -name test-suite.log -exec cat {} \; && false; fi
make install
make dist
mv -- *.tar.gz "$UPLOAD_FILES_PATH"
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
mv -- *.tar.gz "$UPLOAD_FILES_PATH"
popd
popd

# build agent-ovs
pushd agent-ovs
./autogen.sh
./configure --prefix="$ROOT" \
    --with-buildversion="$BUILD_NUMBER" \
    CPPFLAGS="-isystem $ROOT/include" \
    CXXFLAGS="-Wall"
make -j4
if ! make check; then find . -name test-suite.log -exec cat {} \; && false; fi
make dist
mv -- *.tar.gz "$UPLOAD_FILES_PATH"
popd
