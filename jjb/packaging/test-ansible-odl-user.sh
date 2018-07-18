#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
source rpm_build/bin/activate
rpm_build/bin/python -m pip install --upgrade pip

# Install Ansible
sudo yum install -y ansible

# Install local version of ansible-opendaylight to path expected by Ansible.
# Could almost do this by setting ANSIBLE_ROLES_PATH=$WORKSPACE, but Ansible
# expects the dir containing the role to have the name of role. The JJB project
# is called "ansible", which causes the cloned repo name to not match the role
# name "opendaylight". So we need a cp/mv either way and this is simplest.
sudo cp -R $WORKSPACE/ansible /etc/ansible/roles/opendaylight

# Install OpenDaylight via repo using example Ansible playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/examples/rpm_8_devel.yml

# Create Ansible custom module directories
sudo mkdir -p /usr/share/ansible/plugins/modules

# Copy the custom module to the directory above
sudo cp $WORKSPACE/ansible/library/odl_usermod.py /usr/share/ansible/plugins/modules/

# Execute the tests playnook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-users.yaml -vvv
