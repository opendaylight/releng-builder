#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Wait for any background apt processes to finish
# There seems to be a backgroud apt process that locks /var/lib/dpkg/lock
# and causes our apt commands to fail.
while pgrep apt > /dev/null; do sleep 1; done

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
