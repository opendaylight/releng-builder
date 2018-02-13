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

# Start OpenDaylight
sudo systemctl start opendaylight

# Check systemd status of OpenDaylight, will fail if rc is nonzero
sudo systemctl status opendaylight

# Sleep for a bit because it sometimes takes some seconds for the java process to start
sleep 5

# Verify Java process is running, will fail if rc is nonzero
pgrep java
