#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

env | grep -E "STREAM|SILO" > env-file

scripts_path=/builder/jjb/packaging

docker_id=$(sudo docker run --env-file env-file --name build_rpm_suse -di --cap-add=SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro opensuse /usr/lib/systemd/systemd)

sudo docker cp $(pwd)/packaging/ $docker_id:/packaging

sudo docker exec $docker_id /usr/bin/zypper -n install curl expect nmap sudo openssh python-virtualenv python rpmdevtools rpmbuild git

sudo docker exec $docker_id git clone https://git.opendaylight.org/gerrit/releng/builder

sudo docker exec $docker_id git -C /builder fetch https://git.opendaylight.org/gerrit/releng/builder refs/changes/01/68201/26

sudo docker exec $docker_id git -C /builder checkout FETCH_HEAD

sudo docker exec $docker_id /bin/bash $scripts_path/build-rpm-snap.sh
