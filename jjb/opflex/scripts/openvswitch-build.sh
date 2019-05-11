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
# Build script for openvswitch

set -e
set -x

echo "---> scripts/openvswitch-build.sh"

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR"

./boot.sh
./configure --prefix="$ROOT" --enable-shared
make -j4
DESTDIR=$(pwd)/$DESTDIR make install

if [[ $OPENVSWITCH_VERSION =~ 2.6.0 ]]; then
    mkdir -p $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openvswitch/*.h $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openflow $DESTDIR/$ROOT/include/openvswitch
    cp -t "$DESTDIR/$ROOT/include/openvswitch/" include/*.h
    find lib -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;
elif [[ $OPENVSWITCH_VERSION =~ noiro ]]; then
    find lib ofproto -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;
fi

pushd $DESTDIR
tar -cvzf -- "openvswitch-$OPENVSWITCH_VERSION.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv -- *.tar.gz "$_"
popd
