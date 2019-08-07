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

# Wait up to 60 seconds for ODL's Java process to start
for i in $(seq 20); do
  # shellcheck disable=SC2015
  pgrep java && break || sleep 3
  echo "Waited $((i * 3)) seconds for ODL Java process to start"
done

# Verify Java process is running, will fail if rc is nonzero
pgrep java
