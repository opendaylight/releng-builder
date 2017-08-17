#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
# shellcheck disable=SC1091
source rpm_build/bin/activate
PYTHON="rpm_build/bin/python"
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r "$WORKSPACE/packaging/packages/requirements.txt"

# Make a URL for the tarball artifact from DOWNLOAD_URL (a zip)
# shellcheck disable=SC2154
download_url="${{DOWNLOAD_URL//zip/tar.gz}}"

# Build release specified by build params
"$WORKSPACE/packaging/packages/build.py" --rpm --download_url "$download_url" \
                                    --changelog_name "$CHANGELOG_NAME" \
                                    --changelog_email "$CHANGELOG_EMAIL"

# Move RPMs (SRPM and noarch) to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv "/home/$USER/rpmbuild/RPMS/noarch/"*.rpm "$_"
mv "/home/$USER/rpmbuild/SRPMS/"*.rpm "$_"
