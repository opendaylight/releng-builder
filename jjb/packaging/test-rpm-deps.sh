#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Requirements for package where SRPM was built into noarch on CentOS CBS
# rpm -qp opendaylight-8.0.0-0.1.20171125rel2049.el7.noarch.rpm --requires
# shellcheck disable=SC2034
declare -a expected_deps=( "/bin/bash"
                           "/bin/sh"
                           "/usr/bin/env"
                           "java >= 1:1.8.0"
                           "rpmlib(CompressedFileNames) <= 3.0.4-1"
                           "rpmlib(FileDigests) <= 4.6.0-1"
                           "rpmlib(PartialHardlinkSets) <= 4.0.4-1"
                           "rpmlib(PayloadFilesHavePrefix) <= 4.0-1"
                           "shadow-utils"
                           "rpmlib(PayloadIsXz) <= 5.2-1" )

# Verify exactly 1 RPM is in the path we expect
set -- /home/$USER/rpmbuild/RPMS/noarch/*.rpm
# shellcheck disable=SC1054
[ $# -eq 1 ] || {{ echo "Expected 1 RPM, found $#"; exit 1; }}

# shellcheck disable=SC2034
mapfile -t actual_deps < <( rpm -qp /home/$USER/rpmbuild/RPMS/noarch/*.rpm --requires )
# shellcheck disable=SC2154 disable=SC2145
printf 'Dependency found: %s\n' "${{actual_deps[@]}}"

# shellcheck disable=SC2154 disable=SC2145 disable=SC2034
diff_deps=(`echo "${{expected_deps[@]}}" "${{actual_deps[@]}}" | tr ' ' '\n' | sort | uniq -u`)
# shellcheck disable=SC2154 disable=SC2145 disable=SC2068 disable=SC2170 disable=SC1083
if [ ${{#diff_deps[*]}} -eq 0 ]; then
    echo "RPM requirements are as expected"
else
    echo "RPM requirements don't match the expected requirements"
    # shellcheck disable=SC2154 disable=SC2145
    printf 'Dependency mismatch: %s\n' ${{diff_deps[@]}}
    exit 1
fi
