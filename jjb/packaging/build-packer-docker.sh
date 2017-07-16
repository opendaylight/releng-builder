#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install Docker
curl -fsSL https://get.docker.com/ | sh
sudo usermod -aG docker jenkins
sudo systemctl start docker

# Build artifacts specified by build params
cd $WORKSPACE/packaging/packer
# To show packer debug info, uncomment the next line and add -E flag to sudo
#export PACKER_LOG=1
sudo /usr/local/bin/packer build -var "docker_repo=$DOCKER_REPO" \
                                 -var "odl_version=$ODL_VERSION" \
                                 -var "os_name=$OS_NAME" \
                                 -var "os_version=$OS_VERSION" \
                                 -var "rpm_repo_url=$RPM_REPO_URL" \
                                  templates/docker.json

# TODO: Publish build artifact
