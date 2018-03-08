#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

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
elif [ -f /usr/bin/dpkg ]; then
  # Uninstall ODL
  sudo dpkg --purge opendaylight

  # Verify ODL not installed
  if dpkg -s opendaylight; then
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
