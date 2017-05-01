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

# Install ODL from .deb link or .repo url
if [[ $PACKAGE == *.deb ]]
then
  # shellcheck disable=SC2154
  pkg_basename="${{PACKAGE##*/}}"
  # NB: Apt can't install directly from URL, so need this intermediary file
  curl -o "$pkg_basename" "$PACKAGE"
  dpkg --install ./"$pkg_basename"
elif [[ $PACKAGE == ppa:* ]]
then
  sudo add-apt-repository "$PACKAGE"
  sudo apt-get update
  sudo apt-get install -y opendaylight
else
  echo "URL is not a link to a PPA repo or .deb"
fi

# Install expect to interact with karaf shell
sudo apt-get install -y expect

# Start OpenDaylight
sudo systemctl start opendaylight

# Check status of OpenDaylight
sudo systemctl status opendaylight

# Get process id of Java
pgrep java
