#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
source rpm_build/bin/activate
pip install --upgrade pip
sudo yum install -y ansible

# https://github.com/dfarrell07/vagrant-opendaylight#ansible-deployments
git clone https://github.com/dfarrell07/vagrant-opendaylight.git
pushd vagrant-opendaylight

ansible-galaxy install -r requirements.yml -p provisioning/roles/ --force

# Add more tests