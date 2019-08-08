#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail
PACKAGE=${PACKAGE:-"$WORKSPACE/packaging/packages/deb/opendaylight/*.deb"}
URL_REGEX='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
# Wait for any background apt processes to finish
# There seems to be a backgroud apt process that locks /var/lib/dpkg/lock
# and causes our apt commands to fail.
while pgrep apt > /dev/null; do sleep 1; done

# Install ODL from .deb link or .repo url
if [[ $PACKAGE =~ $URL_REGEX ]]
then
  # shellcheck disable=SC2154
  pkg_basename="${PACKAGE##*/}"
  curl -L --silent -o "$pkg_basename" "$PACKAGE"
  sudo dpkg --install ./"$pkg_basename"
elif [[ $PACKAGE == *.deb ]]
then
  echo "$PACKAGE"
  sudo dpkg --install "$PACKAGE"
elif [[ $PACKAGE == ppa:* ]]
then
  sudo add-apt-repository "$PACKAGE"
  sudo apt-get update
  sudo apt-get install -y opendaylight
else
  echo "URL is not a link to a PPA repo or .deb"
  exit 1
fi
