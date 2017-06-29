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
                    python-jinja2 \
                    python-bs4 \
                    python-requests \
                    python-tzlocal \
                    gdebi

# Build release specified by build params
"$WORKSPACE/packaging/packages/build.py" --deb --download_url "$DOWNLOAD_URL" \
                                  --changelog_name "$CHANGELOG_NAME" \
                                  --changelog_email "$CHANGELOG_EMAIL"
