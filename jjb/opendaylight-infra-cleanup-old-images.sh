#!/bin/bash

# install lftools from the script in global-jjb
global-jjb/shell/lftools-install.sh
# shellcheck disable=SC1090
source "$LFTOOLS_DIR/bin/activate"

lftools openstack --os-cloud odlpriv-sandbox \
    image cleanup --hide-public=True \
                  --days=30 \
                  --clouds=odlpriv-sandbox,rackspace
