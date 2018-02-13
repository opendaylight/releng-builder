#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

#-------------------------------------------------------------------------------
# Exit if epel
#-------------------------------------------------------------------------------
# Jenkins template and scripts are shared between suse and red hat to build and
# test the rpms. However, all the suse processing is done in a container whereas
# redhat processing is done in a VM. This script does the build in a VM
#-------------------------------------------------------------------------------
if [ "$DISTRO" == "epel-7" ]; then
  echo "Nothing to do for epel"
  exit 0
fi

env | grep -E "STREAM|SILO" > env-file

scripts_path=/builder/jjb/packaging

docker_id=$(sudo docker run --env-file env-file --name build_rpm_suse -di --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro opensuse /usr/lib/systemd/systemd)

sudo docker cp "$(pwd)"/packaging/ $docker_id:/packaging

sudo docker exec $docker_id /usr/bin/zypper -n install curl expect nmap sudo openssh python-virtualenv python rpmdevtools rpmbuild git

sudo docker exec $docker_id git clone https://git.opendaylight.org/gerrit/releng/builder

sudo docker exec $docker_id git -C /builder fetch https://git.opendaylight.org/gerrit/releng/builder refs/changes/01/68201/30

sudo docker exec $docker_id git -C /builder checkout FETCH_HEAD

sudo docker exec $docker_id /bin/bash $scripts_path/build-rpm-snap.sh
