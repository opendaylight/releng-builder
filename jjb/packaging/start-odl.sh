#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

#-------------------------------------------------------------------------------
# Exit if opensuse and in a VM
#-------------------------------------------------------------------------------
# Jenkins template and scripts are shared between suse and red hat to build and
# test the rpms. However, all the suse processing is done in a container whereas
# redhat processing is done in a VM. We should exit if we detect that this
# script is going to test a opensuse rpm inside a VM. DISTRO variable only
# exists when the script is executed in the VM.
#-------------------------------------------------------------------------------

if [ "$DISTRO" == "opensuse-42" ]; then
  echo "We are in a VM, nothing to do for opensuse"
  exit 0
fi

# Start OpenDaylight
sudo systemctl start opendaylight

# Check systemd status of OpenDaylight, will fail if rc is nonzero
sudo systemctl status opendaylight

# Wait 60 seconds for the java process to start
for i in $(seq 20); do
  pgrep java && break || sleep 3
done

# Verify Java process is running, will fail if rc is nonzero
pgrep java
