#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Start OpenDaylight
sudo systemctl stop opendaylight

# Check systemd status of OpenDaylight, will fail if nonzero
sudo systemctl status opendaylight

# Verify Java process is not running
if pgrep java; then
  exit $?
fi
