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
if ps aux | grep "[o]pendaylight"; then
  # Fail if exit code 0, ie Java process is running
  echo "OpenDaylight process unexpectedly still running"
  exit 1
else
  echo "OpenDaylight process not running, as expected"
fi
