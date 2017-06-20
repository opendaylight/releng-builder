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
$PYTHON -m pip install -r "$WORKSPACE/packaging/rpm/requirements.txt"

# Make a URL for the tarball artifact from DOWNLOAD_URL (a zip)
# shellcheck disable=SC2154
download_url="${{DOWNLOAD_URL//zip/tar.gz}}"

# Build release specified by build params
"$WORKSPACE/packaging/rpm/build.py" --download_url "$download_url" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"

# Copy the rpm to be upload
UPLOAD_FILES_PATH="$WORKSPACE/archives/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
cp /home/jenkins/rpmbuild/{SRPMS,RPMS/noarch}/*.rpm "$_" || true
