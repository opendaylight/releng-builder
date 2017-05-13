#!/bin/bash
LFTOOLS_DIR="$WORKSPACE/.venv-lftools"
if [ ! -d "$LFTOOLS_DIR" ]
then
    virtualenv "$LFTOOLS_DIR"
    # shellcheck disable=SC1090
    source "$LFTOOLS_DIR/bin/activate"
    pip install --upgrade pip
    pip install "lftools>=0.0.10"
    pip freeze
fi
# shellcheck disable=SC1090
source "$LFTOOLS_DIR/bin/activate"

lftools openstack --os-cloud rackspace \
    server list --days=1
lftools openstack --os-cloud rackspace \
    server cleanup --days=1
