#!/bin/bash

# Install OpenDaylight via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/deb_repo_api.yml --extra-vars "@$WORKSPACE/ansible/examples/log_vars.json"
