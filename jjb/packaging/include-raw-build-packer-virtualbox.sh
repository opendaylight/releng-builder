#!/bin/bash

# Build release specified by build params
packer build -var "docker_repo=$DOCKER_REPO" \
             -var "guest_os_type=$GUEST_OS_TYPE" \
             -var "odl_version=$odl_version" \
             -var "os_name=$OS_NAME" \
             -var "os_version=$OS_VERSION" \
             -var "rpm_repo_file=$RPM_REPO_FILE" \
             -var "rpm_repo_url=$RPM_REPO_URL"
