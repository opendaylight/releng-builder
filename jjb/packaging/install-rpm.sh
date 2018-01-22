#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Update mirror list to avoid slow/hung one
sudo yum update -y yum-plugin-fastestmirror

# Install ODL from RPM path, RPM URL or .repo file url
# NB: Paths must be anchored at root
if [[ $URL == /*  ]]; then
  # If path is globbed (/path/to/*.rpm), expand it
  path=$(sudo find / -wholename $URL)
  sudo yum install -y "$path"
elif [[ $URL == *.rpm ]]; then
  sudo yum install -y "$URL"
elif [[ $URL == *.repo ]]; then
  # FIXME: This fails when called via a macro at brace expansion
  # shellcheck disable=SC2154
  repo_file="${URL##*/}"
  sudo curl --silent -o /etc/yum.repos.d/"$repo_file" "$URL"
  sudo yum install -y opendaylight
else
  echo "URL is not a link to .rpm or .repo"
  exit 1
fi
