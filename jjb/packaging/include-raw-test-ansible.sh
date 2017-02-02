#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv build
source build/bin/activate
pip install --upgrade pip

git clone https://github.com/dfarrell07/ansible-opendaylight.git

# Check if the OS is Debian based
if [ -f /etc/lsb-release ]; then
  sudo apt-add-repository ppa:ansible/ansible
  sudo apt-get update
  sudo apt-get install -y ansible
  # Check if the OS is RedHat based
elif [ -f /etc/redhat-release ]; then
  sudo yum install -y ansible
fi

cd ansible-opendaylight
sudo ansible-galaxy install -r requirements.yml

if [ -f /etc/lsb-release ]; then
	sudo ansible-playbook -i "localhost," -c local examples/deb_repo_install_playbook.yml
elif [ -f /etc/redhat-release ]; then
   sudo ansible-playbook -i "localhost," -c local examples/odl_4_testing_playbook.yml
fi

# Add more tests