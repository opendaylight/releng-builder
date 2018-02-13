#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

env | grep -E "STREAM|SILO" > env-file

scripts_path=/builder/jjb/packaging

docker_id=$(sudo docker run --env-file env-file -di --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro opensuse /usr/lib/systemd/systemd)

sudo docker cp "$(pwd)"/packaging/ $docker_id:/packaging

sudo docker exec $docker_id /usr/bin/zypper -n install curl expect nmap sudo openssh python-virtualenv python rpmdevtools rpmbuild git

sudo docker exec $docker_id git clone https://git.opendaylight.org/gerrit/releng/builder

# These two lines are just added to try the patch in CI
sudo docker exec $docker_id git -C /builder fetch https://git.opendaylight.org/gerrit/releng/builder refs/changes/01/68201/23
sudo docker exec $docker_id git -C /builder checkout FETCH_HEAD

sudo docker exec $docker_id /bin/bash $scripts_path/build-rpm-snap.sh

sudo docker exec $docker_id /bin/bash $scripts_path/test-rpm-deps.sh

sudo docker exec $docker_id /bin/bash $scripts_path/install-rpm.sh

sudo docker exec $docker_id /bin/bash $scripts_path/start-odl.sh

sudo docker exec $docker_id /bin/bash $scripts_path/test-ports-nofeature.sh

sudo docker exec $docker_id /usr/bin/expect $scripts_path/test-karaf.expect

sudo docker exec $docker_id /bin/bash $scripts_path/test-rest-ok.sh

sudo docker exec $docker_id /bin/bash $scripts_path/stop-odl.sh

sudo docker exec $docker_id /bin/bash $scripts_path/uninstall-rpm.sh

if [ "$SILO" == "sandbox" ]; then
  echo "Not uploading RPMs to Nexus because we are in the Sandbox"
elif [ "$SILO" == "releng" ]; then
  UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
  RPM_NAME=$(sudo docker exec $docker_id find /root/rpmbuild/RPMS/noarch/ -wholename '*.rpm')
  SRPM_NAME=$(sudo docker exec $docker_id find /root/rpmbuild/SRPMS/ -wholename '*.rpm')
  mkdir -p "$UPLOAD_FILES_PATH"

  sudo docker cp $docker_id:$RPM_NAME "$_"

  sudo docker cp $docker_id:$SRPM_NAME "$_"
fi
