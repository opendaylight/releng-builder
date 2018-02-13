#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Start OpenDaylight
sudo systemctl start opendaylight

# Check systemd status of OpenDaylight, will fail if rc is nonzero
sudo systemctl status opendaylight

# Sleep for a bit because it sometimes takes some seconds for the java process to start
sleep 5

# Verify Java process is running, will fail if rc is nonzero
pgrep java
