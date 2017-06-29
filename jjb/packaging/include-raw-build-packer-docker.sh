#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

cd $WORKSPACE/packaging/packer
# Install required packages

# Build release specified by build params
packer build -var "docker_repo=$DOCKER_REPO" \
             -var "odl_version=$odl_version" \
             -var "os_name=$OS_NAME" \
             -var "os_version=$OS_VERSION" \
             -var "rpm_repo_file=$RPM_REPO_FILE" \
             -var "rpm_repo_url=$RPM_REPO_URL"
