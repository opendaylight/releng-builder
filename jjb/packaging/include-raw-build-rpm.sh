#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
venv rpm_build
source ./bin/activate
pip install --upgrade pip
pip install -r $WORKSPACE/requirements.txt

# Build release specified by build params
./$WORKSPACE/packaging/rpm/build.py --major $VERSION_MAJOR \
                                    --minor $VERSION_MINOR \
                                    --patch $VERSION_PATCH \
                                    --rpm $RPM_RELEASE \
                                    --sysd_commit $SYSD_COMMIT \
                                    --codename $CODENAME \
                                    --download_url $DOWNLOAD_URL \
                                    --changelog_date $CHANGELOG_DATE \
                                    --changelog_name $CHANGELOG_NAME \
                                    --changelog_email $CHANGELOG_EMAIL
