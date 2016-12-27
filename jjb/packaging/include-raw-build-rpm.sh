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
$WORKSPACE/packaging/rpm/build.py --download_url "$DOWNLOAD_URL" \
                                  --sysd_commit "$SYSD_COMMIT" \
                                  --changelog_date "$CHANGELOG_DATE" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"
