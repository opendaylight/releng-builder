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

FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
FACTER_OSVER=$(/usr/bin/facter operatingsystemrelease)
case $FACTER_OS in
    Ubuntu)
        #todo: remove the below hack once the issue is resolved in
        #images.
        sudo sed -i "/127.0.0.1/s/$/ $(hostname)/" /etc/hosts || true
        ;;
esac

chmod a+x "$(pwd)/pkgsrc/dev_compile_script.sh"
sudo /bin/bash "$(pwd)/pkgsrc/dev_compile_script.sh" -p -d -b -v "$QUAGGA_VERSION" || true

# Move packages into a that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
#mv $(pwd)/pkgsrc/*.{deb,rpm} "$_" || true
ls $(pwd)/pkgsrc/
mv $(pwd)/pkgsrc/*.rpm "$UPLOAD_FILES_PATH" || true
mv $(pwd)/pkgsrc/*.deb "$UPLOAD_FILES_PATH" || true
#mv "/home/$USER/rpmbuild/RPMS/noarch/"*.rpm "$_" || true
#mv "/home/$USER/rpmbuild/SRPMS/"*.rpm "$_" || true
popd
