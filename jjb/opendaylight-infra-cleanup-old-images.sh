#!/bin/bash

lftools openstack --os-cloud odlpriv-sandbox \
    image cleanup --hide-public=True \
                  --days=30 \
                  --clouds=odlpriv-sandbox,rackspace
