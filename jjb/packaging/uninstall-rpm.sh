#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

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
