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
sudo "$(pwd)/pkgsrc/dev_compile_script.sh" -p -d -b -v "$QUAGGA_VERSION" || true
# Create tarballs of the binaries and sources
if [ `facter operatingsystem` = "Ubuntu" ]; then
     HOST_NAME=Ubuntu
     echo "its Created Debian packages on Ubuntu-Host" ;
elif [ `facter operatingsystem` = "CentOS" ] ; then
    HOST_NAME=CentOS
    echo "its created rpms on CentOS-Host" ;
fi
case $HOST_NAME in
    CentOS)
        echo "CentOS VM"
        tar -cvzf "quagga-$QUAGGA_VERSION.0.tar.gz"  $(pwd)/pkgsrc/*.rpm
        ;;
    Ubuntu)
	echo "Ubuntu VM"
        tar -cvzf "quagga-$QUAGGA_VERSION.0.tar.gz"  $(pwd)/pkgsrc/*.deb
       	;;
esac   
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
