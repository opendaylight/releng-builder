#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the term s of the Eclipse Public License
# v1.0 accompanies testing this distribution with Netvirt jobs, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> quagga-build.sh"

set -e -x

# The script builds 6wind/quagga source and binary packages from zrpcd
# repository for testing router functionalities with Netvirt jobs, .

pushd "$(pwd)/zrpcd"

FACTER_OS=$(/usr/bin/facter operatingsystem | tr '[:upper:]' '[:lower:]')
FACTER_OSVER=$(/usr/bin/facter operatingsystemrelease)

chmod a+x "$(pwd)/pkgsrc/dev_compile_script.sh"
sudo "$(pwd)/pkgsrc/dev_compile_script.sh" -p -d -b -v "$QUAGGA_VERSION" || true

# Move packages into a that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"

ls -R "$(pwd)/pkgsrc/"
mv "$(pwd)/pkgsrc/"*.rpm "$UPLOAD_FILES_PATH" || true
mv "$(pwd)/pkgsrc/"*.deb "$UPLOAD_FILES_PATH" || true
mv "/home/$USER/rpmbuild/RPMS/noarch/"*.rpm "$_" || true
mv "/home/$USER/rpmbuild/SRPMS/"*.rpm "$_" || true
mv "/root/rpmbuild/SRPMS/"*.rpm "$_" || true
popd
