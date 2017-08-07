#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
source rpm_build/bin/activate
PYTHON="rpm_build/bin/python"
$PYTHON -m pip install --upgrade pip
sudo yum install -y ansible

git clone https://github.com/dfarrell07/ansible-opendaylight.git
cd ansible-opendaylight
sudo ansible-galaxy install -r requirements.yml
sudo ansible-playbook -i "localhost," -c local examples/odl_6_testing_playbook.yml

# Add more tests
