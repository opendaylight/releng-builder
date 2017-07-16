#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail


# Install required packages

cd /etc/yum.repos.d
sudo wget http://download.virtualbox.org/virtualbox/rpm/rhel/virtualbox.repo
sudo yum -y groupinstall "Development Tools"
sudo yum -y install kernel-devel
sudo yum --enablerepo=epel -y install dkms
sudo yum -y install VirtualBox-5.1

cd $WORKSPACE/packaging/packer
wget https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_linux_amd64.zip
unzip packer_1.0.3_linux_amd64.zip

# Build release specified by build params
sudo ./packer build -var "guest_os_type=$GUEST_OS_TYPE" \
                    -var "odl_version=$ODL_VERSION" \
                    -var "os_name=$OS_NAME" \
                    -var "os_version=$OS_VERSION" \
                    -var "rpm_repo_url=$RPM_REPO_URL" \
                    -var "iso_urls=$ISO_URLS" \
                    -var "iso_checksum=$ISO_CHECKSUM" \
                    templates/virtualbox.json
