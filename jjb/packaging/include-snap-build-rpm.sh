#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
virtualenv rpm_build
source rpm_build/bin/activate
pip install --upgrade pip
pip install -r $WORKSPACE/packaging/rpm/requirements.txt

# Build release specified by build params
$WORKSPACE/packaging/rpm/build.py --build-latest-snap \
                                  --major "$VERSION_MAJOR" \
                                  --minor "$VERSION_MINOR" \
                                  --patch "$VERSION_PATCH" \
                                  --rpm "$RPM_RELEASE" \
                                  --sysd_commit "$SYSD_COMMIT" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"
