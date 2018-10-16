#!/bin/bash

# Install OpenDaylight via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/deb_repo_api.yml

# Create Ansible custom module directories
sudo mkdir -p /usr/share/ansible/plugins/modules

# Copy the custom module to the directory above
sudo cp $WORKSPACE/ansible/library/odl_usermod.py /usr/share/ansible/plugins/modules/

# Execute the odl-user-test playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-users.yaml -v

# Test the custom log configurations
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-logs.yaml -e test_log_level=INFO -e test_log_mechanism=file -v
