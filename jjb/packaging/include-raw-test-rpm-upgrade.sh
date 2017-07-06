#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Stop ODL systemd service before upgrade
sudo systemctl stop opendaylight

# Show ODL version before upgrade
sudo yum info opendaylight

# Install old ODL from .rpm link or .repo url
if [[ $UPGRADE_URL == *.rpm ]]
then
  sudo yum upgrade -y "$UPGRADE_URL"
elif [[ $UPGRADE_URL == *.repo ]]
then
  # shellcheck disable=SC2154
  repo_file="${{UPGRADE_URL##*/}}"
  sudo curl --silent -o /etc/yum.repos.d/"$repo_file" "$UPGRADE_URL"
  sudo yum upgrade -y opendaylight
else
  echo "URL is not a link to .rpm or .repo"
  exit 1
fi

# Show ODL version after upgrade
sudo yum info opendaylight
