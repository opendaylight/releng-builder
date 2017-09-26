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
echo "---> quagga-build.sh"

set -e -x

# Compile and install 6wind/quagga for router functionalities
pushd "$(pwd)/zrpcd"
chmod a+x "$(pwd)/pkgsrc/dev_compile_script.sh"
sudo "$(pwd)/pkgsrc/dev_compile_script.sh" -d -b -t -v "$QUAGGA_VERSION" || true
# Create tarballs of the binaries and sources
tar -cvzf "quagga-$QUAGGA_VERSION.0.tar.gz" /opt/quagga
tar -cvzf "quagga-src-$QUAGGA_VERSION.0.tar.gz" "$(pwd)/zrpcd"
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
