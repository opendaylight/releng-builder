#!/bin/bash

##############################################################################
## Copyright (c) 2018 Intracom Telecom and others.
##
## All rights reserved. This program and the accompanying materials
## are made available under the terms of the Apache License, Version 2.0
## which accompanies this distribution, and is available at
## http://www.apache.org/licenses/LICENSE-2.0
###############################################################################

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Verify exactly 1 deb is in the path we expect
set -- "$WORKSPACE"/packaging/packages/deb/opendaylight/*.deb
if [ $# -eq 1 ]; then
    echo "Found one deb in build out dir, as expected"
else
    echo "Expected 1 deb, found $#"
    echo 1
fi

# If path is globbed (/path/to/*.deb), expand it
path=$(sudo find / -wholename "$WORKSPACE"/packaging/packages/deb/opendaylight/*.deb)

# If no deb found, fail clearly
if [ -z "$path" ]; then
    echo "deb not found"
    exit 1
fi


if [ -f /usr/bin/dpkg ]; then
    declare -a expected_deps=( "init-system-helpers (>= 1.18~)"
                               "lsb-base (>= 4.1+Debian11ubuntu7)"
                               "adduser"
                               "openjdk-8-jre-headless" )

fi

# shellcheck disable=SC2034
mapfile -t actual_deps < <( dpkg -I "$WORKSPACE"/packaging/packages/deb/opendaylight/*.deb | grep Depends | sed 's/Depends: //g' | sed 's/,/\n/g' )
# shellcheck disable=SC2154 disable=SC2145
printf 'Dependency found: %s\n' "${actual_deps[@]}"

# shellcheck disable=SC2154,SC2145,SC2034,SC2207
diff_deps=($(echo "${expected_deps[@]}" "${actual_deps[@]}" | tr ' ' '\n' | sort | uniq -u))

# shellcheck disable=SC2154 disable=SC2145 disable=SC2068 disable=SC2170 disable=SC1083
if [ ${#diff_deps[*]} -eq 0 ]; then
    echo "deb requirements are as expected"
else
    echo "deb requirements don't match the expected requirements"
    # shellcheck disable=SC2154 disable=SC2145
    printf 'Dependency mismatch: %s\n' ${diff_deps[@]}
    exit 1
fi
