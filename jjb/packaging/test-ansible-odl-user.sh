# Create Ansible custom module directories
sudo mkdir -p /usr/share/ansible/plugins/modules

# Copy the custom module to the directory above
sudo cp $WORKSPACE/ansible/library/odl_usermod.py /usr/share/ansible/plugins/modules/

# Execute the odl-user-test playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-users.yaml -v
