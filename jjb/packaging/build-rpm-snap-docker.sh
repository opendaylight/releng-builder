#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

env | grep STREAM > env-file

scripts_path=/builder/jjb/packaging

docker_id=$(sudo docker run --env-file env-file --name build_rpm_epel -di --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro centos /usr/lib/systemd/systemd)

sudo docker cp "$(pwd)"/packaging/ $docker_id:/packaging

sudo docker exec $docker_id /usr/bin/yum -y install sudo rpmdevtools rpmbuild git python-virtualenv python

# Just to test this patch. As soon as this get merged, we will remove the three lines
sudo docker exec $docker_id git clone https://git.opendaylight.org/gerrit/releng/builder
sudo docker exec $docker_id git --git-dir /builder/.git --work-tree /builder fetch https://git.opendaylight.org/gerrit/releng/builder refs/changes/61/68861/10
sudo docker exec $docker_id git --git-dir /builder/.git --work-tree /builder checkout FETCH_HEAD

sudo docker exec $docker_id /bin/bash $scripts_path/build-rpm-snap.sh
