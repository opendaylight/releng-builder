#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

cd $WORKSPACE/packaging/packer
# Install required packages
wget https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_linux_amd64.zip
unzip packer_1.0.3_linux_amd64.zip
sudo yum -y install kvm libvirt
sudo service libvirtd start

# Build release specified by build params
sudo ./packer build -var "iso_checksum=$ISO_CHECKSUM" \
                    -var "iso_urls=$ISO_URLS" \
                    -var "odl_version=$ODL_VERSION" \
                    -var "os_name=$OS_NAME" \
                    -var "os_version=$OS_VERSION" \
                    -var "rpm_repo_url=$RPM_REPO_URL" \
                    templates/libvirt.json
