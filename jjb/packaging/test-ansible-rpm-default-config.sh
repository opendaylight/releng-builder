#!/bin/bash

# Install OpenDaylight with custom config via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/rpm_8_devel_odl_api.yml

# Create Ansible custom module directories
sudo mkdir -p /usr/share/ansible/plugins/modules

# Copy the custom module to the directory above
sudo cp $WORKSPACE/ansible/library/odl_usermod.py /usr/share/ansible/plugins/modules/

# Execute the odl-user-test playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-users.yaml -v

# Test the custom log configurations
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-logs.yaml --extra-vars test_log_level=INFO -v