#!/bin/bash

# shellcheck disable=SC1090
source "$WORKSPACE/.virtualenvs/lftools/bin/activate"

lftools openstack --os-cloud rackspace \
    server list --days=1
lftools openstack --os-cloud rackspace \
    server cleanup --days=1
