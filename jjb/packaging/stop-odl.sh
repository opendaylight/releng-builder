#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Stop OpenDaylight
sudo systemctl stop opendaylight

# Check systemd status of OpenDaylight
# NB: Exit code 3 means service isn't running, including after clean exit
set +e
sudo systemctl status opendaylight
if [ $? -ne 3 ]; then
  echo "OpenDaylight systemd service unexpectedly not stopped"
  exit 1
else
  echo "OpenDaylight systemd service stopped, as expected"
fi
set -e

# Verify Java process is not running
# shellcheck disable=SC2009
if ps aux | grep "[o]pendaylight"; then
  # Fail if exit code 0, ie Java process is running
  echo "OpenDaylight process unexpectedly still running"
  exit 1
else
  echo "OpenDaylight process not running, as expected"
fi
