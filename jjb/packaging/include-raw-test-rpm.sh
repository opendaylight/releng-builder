#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install ODL from .rpm link or .repo url
if [[ $URL == *.rpm ]]
then
  sudo yum install -y "$URL"
elif [[ $URL == *.repo ]]
then
  # shellcheck disable=SC2154
  repo_file="${{URL##*/}}"
  sudo curl --silent -o /etc/yum.repos.d/"$repo_file" "$URL"
  sudo yum install -y opendaylight
else
  echo "URL is not a link to .rpm or .repo"
  exit 1
fi

# Start OpenDaylight
sudo systemctl start opendaylight

# Check status of OpenDaylight
sudo systemctl status opendaylight

# Get process id of Java
pgrep java

# Install expect to interact with karaf shell
sudo yum install -y expect

# Execute expect script to do interactive tests with ODL Karaf shell
expect test-karaf-shell.expect
