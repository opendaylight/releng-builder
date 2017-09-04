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

# Copy the debs to be upload
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
# Note: no source packages are available, since the debs are not built
# from the actual source
mv "$WORKSPACE/packaging/packages/deb/opendaylight/"*.deb "$_"
