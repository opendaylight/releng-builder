#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Verify exactly 1 deb is in the path we expect
set -- $HOME/*.deb
if [ $# -eq 1 ]; then
    echo "Found one deb in build out dir, as expected"
else
    echo "Expected 1 deb, found $#"
    echo 1
fi

# If path is globbed (/path/to/*.deb), expand it
path=$(sudo find / -wholename $HOME/*.deb)

# If no deb found, fail clearly
if [ -z $path ]; then
    echo "deb not found"
    exit 1
fi


if [ -f /usr/bin/apt ]; then
  declare -a expected_deps=( "/bin/bash"
                             "/bin/sh"
                             "java >= 1:1.8.0"

fi

# Karaf 4 distros also have a /usr/bin/env requirement INTPAK-120
if [[ ! $path == *opendaylight-6*  ]]; then
    expected_deps+=( "/usr/bin/env" )
fi

# shellcheck disable=SC2034
mapfile -t actual_deps < <( rpm -qp $HOME/rpmbuild/RPMS/noarch/*.rpm --requires )
# shellcheck disable=SC2154 disable=SC2145
printf 'Dependency found: %s\n' "${actual_deps[@]}"

# shellcheck disable=SC2154,SC2145,SC2034,SC2207
diff_deps=(`echo "${expected_deps[@]}" "${actual_deps[@]}" | tr ' ' '\n' | sort | uniq -u`)

# shellcheck disable=SC2154 disable=SC2145 disable=SC2068 disable=SC2170 disable=SC1083
if [ ${#diff_deps[*]} -eq 0 ]; then
    echo "RPM requirements are as expected"
else
    echo "RPM requirements don't match the expected requirements"
    # shellcheck disable=SC2154 disable=SC2145
    printf 'Dependency mismatch: %s\n' ${diff_deps[@]}
    exit 1
fi
