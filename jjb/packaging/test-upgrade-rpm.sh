#!/bin/bash

# clean any previous installation
sudo yum remove opendaylight

# clean the ODL directory
sudo rm -rf /opt/opendaylight

# Execute the upgrade tests
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-upgrade-rpm.sh
