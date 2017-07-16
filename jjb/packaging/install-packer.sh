#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install Packer
wget --quiet --directory-prefix=/tmp https://releases.hashicorp.com/packer/1.0.3/packer_1.0.3_linux_amd64.zip
sudo unzip /tmp/packer_1.0.3_linux_amd64.zip -d /usr/local/bin/
sudo chown jenkins:jenkins /usr/local/bin/packer
