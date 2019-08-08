#!/bin/bash

# Execute the test ODL logs playbook
sudo ansible-playbook -i "localhost," -c local "$WORKSPACE"/packaging-ansible/tests/test-odl-logs.yaml -v
