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
echo "---> scripts/libuv-build.sh"

set -e
set -x

./autogen.sh
ROOT=/tmp/opflex-prefix
./configure --prefix=$ROOT
mkdir install-root
DESTDIR=$(pwd)/install-root make clean install
pushd install-root
tar -cvzf -- "libuv-$LIBUV_VERSION.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv -- *.tar.gz "$_"
popd
