#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

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
