#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages
sudo apt-get install -y --force-yes \
                    build-essential \
                    devscripts \
                    equivs \
                    dh-systemd \
                    python-yaml \
                    python-jinja2 \
                    gdebi

# Build release specified by build params
"$WORKSPACE/packaging/deb/build.py" --major "$VERSION_MAJOR" \
                                  --minor "$VERSION_MINOR" \
                                  --patch "$VERSION_PATCH" \
                                  --deb "$PKG_VERSION" \
                                  --sysd_commit "$SYSD_COMMIT" \
                                  --codename "$CODENAME" \
                                  --java_version "$JAVA_VERSION" \
                                  --download_url "$DOWNLOAD_URL" \
                                  --changelog_date "$CHANGELOG_DATE" \
                                  --changelog_time "$CHANGELOG_TIME" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"

# Copy the debs to be upload
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
cp ../*.deb "$_" || true
