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
  # Uninstall ODL
  sudo yum remove -y opendaylight

  # Verify ODL not installed
  if yum list installed opendaylight; then
    # Fail if exit code 0, ie ODL is still installed
    echo "OpenDaylight unexpectedly still installed"
    exit 1
  else
    echo "OpenDaylight not installed, as expected"
  fi
elif [ -f /usr/bin/zypper ]; then
  # Uninstall ODL
  sudo zypper -n remove opendaylight

  # Verify ODL not installed
  if zypper search --installed-only opendaylight; then
    # Fail if exit code 0, ie ODL is still installed
    echo "OpenDaylight unexpectedly still installed"
    exit 1
  else
    echo "OpenDaylight not installed, as expected"
  fi
else
  echo "The package manager is not supported (not yum or zypper)"
  exit 1
fi
