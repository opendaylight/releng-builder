#!/bin/bash

# Install OpenDaylight via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/deb_repo_api.yml

# Execute the odl-user-test playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-users.yaml -v

# Test the custom log configurations
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-logs.yaml -e test_log_level=INFO -e test_log_mechanism=file -v
