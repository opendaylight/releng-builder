#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv deb_build
source deb_build/bin/activate
pip install --upgrade pip

# Install latest ansible
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install -y ansible

git clone https://github.com/dfarrell07/ansible-opendaylight.git
cd ansible-opendaylight
sudo ansible-galaxy install -r requirements.yml
sudo ansible-playbook -i "localhost," -c local examples/deb_repo_install_playbook.yml

# Add more tests