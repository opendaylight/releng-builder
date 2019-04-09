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

# Convert stream to numeric ODL major version
if [ "$STREAM" == "fluorine" ]; then
  VERSION_MAJOR=9
elif [ "$STREAM" == "neon" ]; then
  VERSION_MAJOR=10
elif [ "$STREAM" == "sodium" ]; then
  VERSION_MAJOR=11
elif [ "$STREAM" == "magnesium" ]; then
  VERSION_MAJOR=12
elif [ "$STREAM" == "aluminium" ]; then
  VERSION_MAJOR=13
elif [ "$STREAM" == "silicon" ]; then
  VERSION_MAJOR=14
else
  echo "Unable to convert stream to major version"
  echo "MAINTAINER: Update if/else switch above with recent stream/ver pairs"
  exit 1
fi

# Build the latest snapshot matching the given major minor version
"$WORKSPACE/packaging/packages/build.py" --rpm \
                                         --changelog_name "$CHANGELOG_NAME" \
                                         --changelog_email "$CHANGELOG_EMAIL" \
                                         latest_snap \
                                         --major "$VERSION_MAJOR"
