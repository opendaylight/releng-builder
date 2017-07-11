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

# Build the latest snapshot matching the given major minor version
"$WORKSPACE/packaging/rpm/build.py" --build-latest-snap \
                                  --major "$VERSION_MAJOR" \
                                  --minor "$VERSION_MINOR" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"

# Copy the rpm to be upload
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
cp "/home/$USER/rpmbuild/RPMS/noarch/"*.rpm "$_"
cp "/home/$USER/rpmbuild/SRPMS/"*.rpm "$_"
