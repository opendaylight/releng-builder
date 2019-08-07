#!/bin/bash

# Uninstall ODL from previous test
# This is to ensure these tests run independant
# from any other tests
sudo yum remove opendaylight -y

# Remove the ODL directory
sudo rm -rf /opt/opendaylight

# Execute the upgrade tests
sudo ansible-playbook -i "localhost," -c local "$WORKSPACE"/packaging-ansible/tests/test-odl-upgrade.yaml -v
