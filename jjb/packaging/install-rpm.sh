#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

#-------------------------------------------------------------------------------
# Exit if suse and in a VM
#-------------------------------------------------------------------------------
# Jenkins template and scripts are shared between suse and red hat to build and
# test the rpms. However, all the suse processing is done in a container whereas
# redhat processing is done in a VM. We should exit if we detect that this
# script is going to test a suse rpm inside a VM. DISTRO variable only exists
# when the script is executed in the VM.
#-------------------------------------------------------------------------------
if [ "$DISTRO" == "suse" ]; then
  echo "We are in a VM, nothing to do for suse"
  exit 0
fi


if [ -f /usr/bin/yum ]; then
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
    # shellcheck disable=SC2154
    repo_file="${URL##*/}"
    sudo curl --silent -o /etc/yum.repos.d/"$repo_file" "$URL"
    sudo yum install -y opendaylight
  else
    echo "URL is not a link to .rpm or .repo"
    exit 1
  fi
elif [ -f /usr/bin/zypper ]; then
  export URL='/root/rpmbuild/RPMS/noarch/*.rpm'
  # Install ODL from RPM path, RPM URL or .repo file url
  # NB: Paths must be anchored at root
  if [[ $URL == /*  ]]; then
    # If path is globbed (/path/to/*.rpm), expand it
    path=$(sudo find /root -wholename $URL)
    sudo zypper -n --no-gpg-checks install "$path"
  elif [[ $URL == *.rpm ]]; then
    sudo zypper -n --no-gpg-checks install "$URL"
  elif [[ $URL == *.repo ]]; then
    # shellcheck disable=SC2154
    repo_file="${URL##*/}"
    sudo curl --silent -o /etc/zypp/repos.d/"$repo_file" "$URL"
    sudo zypper -n --no-gpg-checks install opendaylight
  else
    echo "URL is not a link to .rpm or .repo"
    exit 1
  fi
else
  echo "The package manager is not supported (not yum or zypper)"
  exit 1
fi
