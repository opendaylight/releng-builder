#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
# shellcheck disable=SC1091
source rpm_build/bin/activate
PYTHON="rpm_build/bin/python"
$PYTHON -m pip install --upgrade pip

# Install Ansible
sudo yum install -y ansible

# Install local version of ansible-opendaylight to path expected by Ansible.
# Could almost do this by setting ANSIBLE_ROLES_PATH=$WORKSPACE, but Ansible
# expects the dir containing the role to have the name of role. The JJB project
# is called "ansible", which causes the cloned repo name to not match the role
# name "opendaylight". So we need a cp/mv either way and this is simplest.
sudo cp -R "$WORKSPACE"/packaging-ansible /etc/ansible/roles/opendaylight
