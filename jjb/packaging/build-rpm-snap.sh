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
# script is going to build a suse rpm inside a VM. DISTRO variable only exists
# when the script is executed in the VM.
#-------------------------------------------------------------------------------
if [ "$DISTRO" == "suse" ]; then
  echo "We are in a VM, nothing to do for suse"
  exit 0
fi

# Install required packages
virtualenv rpm_build
# shellcheck disable=SC1091
source rpm_build/bin/activate
PYTHON="rpm_build/bin/python"
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r "$WORKSPACE/packaging/packages/requirements.txt"

# Convert stream to numeric ODL major version
if [ "$STREAM" == "carbon" ]; then
  VERSION_MAJOR=6
elif [ "$STREAM" == "nitrogen" ]; then
  VERSION_MAJOR=7
elif [ "$STREAM" == "oxygen" ]; then
  VERSION_MAJOR=8
else
  echo "Unable to convert stream to major version"
  exit 1
fi

# Build the latest snapshot matching the given major minor version
"$WORKSPACE/packaging/packages/build.py" --rpm \
                                         --changelog_name "$CHANGELOG_NAME" \
                                         --changelog_email "$CHANGELOG_EMAIL" \
                                         latest_snap \
                                         --major "$VERSION_MAJOR"

# Publish RPMs to Nexus if in production Jenkins, else host on sandbox Jenkins
if [ "$SILO" == "sandbox" ]; then
  # TODO: Host RPMs on Jenkins temporarily
  echo "Not uploading RPMs to Nexus because running in sandbox"
elif  [ "$SILO" == "releng" ]; then
  if [ -f /usr/bin/yum ]; then
    # Move RPMs (SRPM and noarch) to dir of files that will be uploaded to Nexus
    UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
    mkdir -p "$UPLOAD_FILES_PATH"
    cp "/home/$USER/rpmbuild/RPMS/noarch/"*.rpm "$_"
    cp "/home/$USER/rpmbuild/SRPMS/"*.rpm "$_"
  elif [ -f /usr/bin/zypper ]; then
    # Move RPMs (SRPM and noarch) to dir of files that will be uploaded to Nexus
    UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
    mkdir -p "$UPLOAD_FILES_PATH"
    cp "/root/rpmbuild/RPMS/noarch/"*.rpm "$_"
    cp "/root/rpmbuild/SRPMS/"*.rpm "$_"
  fi
else
  echo "Unknown Jenkins silo: $SILO"
  exit 1
fi
