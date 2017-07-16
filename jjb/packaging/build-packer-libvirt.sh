#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install and start libvirt
# TODO: Try removing each of those last 2 pkgs and see which was needed
sudo yum -y install kvm libvirt qemu-kvm
sudo service libvirtd start

# Build artifacts specified by build params
# TODO: Do we need this cd if we use full path to template?
cd $WORKSPACE/packaging/packer
# To show packer debug info, uncomment the next line and add -E flag to sudo
export PACKER_LOG=1
sudo -E /usr/local/bin/packer build -var "iso_checksum=$ISO_CHECKSUM" \
                                    -var "iso_urls=$ISO_URLS" \
                                    -var "odl_version=$ODL_VERSION" \
                                    -var "os_name=$OS_NAME" \
                                    -var "os_version=$OS_VERSION" \
                                    -var "rpm_repo_url=$RPM_REPO_URL" \
                                    templates/libvirt.json || true

# TODO: Publish build artifact
