# Install OpenDaylight via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/rpm_8_devel_odl_api.yml --extra-vars "@$WORKSPACE/ansible/examples/log_vars.json"
