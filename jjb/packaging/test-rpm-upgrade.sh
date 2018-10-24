#!/bin/bash

# Remove any previous installation
sudo yum remove opendaylight

# Delete the ODL directory
sudo rm -rf /opt/opendaylight

# Execute the upgrade tests
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-upgrade.yaml -v
