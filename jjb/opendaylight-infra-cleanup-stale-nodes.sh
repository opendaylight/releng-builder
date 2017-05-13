#!/bin/bash

# install lftools from script in global-jjb
global-jjb/shell/lftools-install.sh
# shellcheck disable=SC1090
source "$LFTOOLS_DIR/bin/activate"

lftools openstack --os-cloud rackspace \
    server list --days=1
lftools openstack --os-cloud rackspace \
    server cleanup --days=1
