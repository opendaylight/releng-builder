#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv deb_build
# shellcheck disable=SC1091
source deb_build/bin/activate
PYTHON="deb_build/bin/python"
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r "$WORKSPACE/packaging/packages/requirements.txt"

# Build release specified by build params
"$WORKSPACE/packaging/packages/build.py" --deb \
                                         --changelog_name "$CHANGELOG_NAME" \
                                         --changelog_email "$CHANGELOG_EMAIL" \
                                         direct \
                                         --download_url "$DOWNLOAD_URL"

# Publish debs to Nexus if in production Jenkins, else host on sandbox Jenkins
if [ "$SILO" == "sandbox" ]; then
  # TODO: Host debs on Jenkins temporarily
  echo "Not uploading debs to Nexus because running in sandbox"
elif  [ "$SILO" == "releng" ]; then
  # Copy the debs to be upload
  # Move debs to dir of files that will be uploaded to Nexus
  UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
  mkdir -p "$UPLOAD_FILES_PATH"
  # Note: no source packages are available, since the debs are not built
  # from the actual source
  cp "$WORKSPACE/packaging/packages/deb/opendaylight/"*.deb "$_"
  cp "$WORKSPACE/packaging/packages/deb/opendaylight/"*.deb "$HOME"
else
  echo "Unknown Jenkins silo: $SILO"
  exit 1
fi
