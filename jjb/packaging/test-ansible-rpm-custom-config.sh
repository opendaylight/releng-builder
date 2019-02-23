#!/bin/bash

# Uninstall any previous installation
sudo yum remove opendaylight -y

# Delete the ODL directory to ensure a clean working enviroment
sudo rm -rf /opt/opendaylight

# Install OpenDaylight with custom config via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/packaging-ansible/examples/rpm_10_devel_odl_api.yml --extra-vars "@$WORKSPACE/packaging-ansible/examples/log_vars.json"

# Create Ansible custom module directories
sudo mkdir -p /usr/share/ansible/plugins/modules

# Copy the custom module to the directory above
sudo cp $WORKSPACE/packaging-ansible/library/odl_usermod.py /usr/share/ansible/plugins/modules/

# Execute the odl-user-test playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/packaging-ansible/tests/test-odl-users.yaml -v

# Test the custom log configurations
#sudo ansible-playbook -i "localhost," -c local $WORKSPACE/packaging-ansible/tests/test-odl-logs.yaml -e test_log_level=DEBUG -e test_log_mechanism=console -v
