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
echo "---> scripts/rapidjson-build.sh"

# Build script for rapidjson

set -e
set -x

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR/$ROOT/lib/pkgconfig"
mkdir -p "$DESTDIR/$ROOT/include"

cp -R include/rapidjson "$DESTDIR/$ROOT/include"
sed -e "s|@INCLUDE_INSTALL_DIR@|$ROOT/include|" \
    -e "s|@PROJECT_NAME@|RapidJSON|" \
    -e "s|@LIB_VERSION_STRING@|1.0.2|" RapidJSON.pc.in > \
    "$DESTDIR/$ROOT/lib/pkgconfig/RapidJSON.pc"

pushd $DESTDIR
tar -cvzf -- "rapidjson-$RAPIDJSON_VERSION.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv -- *.tar.gz "$_"
popd
