#!/bin/bash

# Execute the upgrade tests
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-upgrade.yaml -v
