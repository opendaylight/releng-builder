#!/bin/bash

# shellcheck disable=SC1090
source "$WORKSPACE/.virtualenvs/lftools/bin/activate"

lftools openstack --os-cloud odlpriv-sandbox \
    image cleanup --hide-public=True \
                  --days=30 \
                  --clouds=odlpriv-sandbox,rackspace
