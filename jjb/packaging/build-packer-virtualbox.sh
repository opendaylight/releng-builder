#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install VirtualBox
sudo curl -o /etc/yum.repos.d/virtualbox.repo http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo
sudo yum -y groupinstall "Development Tools"
sudo yum -y install kernel-devel
sudo yum --enablerepo=epel -y install dkms
sudo yum -y install VirtualBox-5.1

# Build artifacts specified by build params
cd $WORKSPACE/packaging/packer
# To show packer debug info, uncomment the next line and add -E flag to sudo
#export PACKER_LOG=1
sudo /usr/local/bin/packer build -var "guest_os_type=$GUEST_OS_TYPE" \
                                 -var "odl_version=$ODL_VERSION" \
                                 -var "os_name=$OS_NAME" \
                                 -var "os_version=$OS_VERSION" \
                                 -var "rpm_repo_url=$RPM_REPO_URL" \
                                 -var "iso_urls=$ISO_URLS" \
                                 -var "iso_checksum=$ISO_CHECKSUM" \
                                 templates/virtualbox.json

# TODO: Publish build artifact
