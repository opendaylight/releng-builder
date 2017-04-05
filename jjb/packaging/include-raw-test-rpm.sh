#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Remove opendaylight if already installed
if rpm -q opendaylight > /dev/null;
then
  sudo yum remove -y opendaylight;
fi

# Install ODL from .rpm link or .repo url
if [[ $URL == *.rpm ]]
then
  sudo yum install -y "$URL"
elif [[ $URL == *.repo ]]
then
  # shellcheck disable=SC2154
  repo_file="${{URL##*/}}"
  sudo curl --silent -o "$repo_file" "$URL"
  sudo yum install -y opendaylight
else
  echo "URL is not a link to .rpm or .repo"
fi

# Install expect to interact with karaf shell
sudo yum install -y expect

# Start OpenDaylight
sudo systemctl start opendaylight

# Check status of OpenDaylight
sudo systemctl status opendaylight

# Get process id of Java
pgrep java
