#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

scripts_path=/builder/jjb/packaging

# A docker container must have been created by the build script
if [ "$DISTRO" == "epel-7" ]; then
  docker_id=$(sudo docker ps -qf name=build_rpm_epel)
  sudo docker exec $docker_id /usr/bin/yum -y install curl expect nmap openssh
elif [ "$DISTRO" == "opensuse-42" ]; then
  docker_id=$(sudo docker ps -qf name=build_rpm_suse)
  sudo docker exec $docker_id /usr/bin/zypper -n install curl expect nmap openssh
fi

sudo docker exec $docker_id /bin/bash $scripts_path/test-rpm-deps.sh

sudo docker exec $docker_id /bin/bash $scripts_path/install-rpm.sh

sudo docker exec $docker_id /bin/bash $scripts_path/start-odl.sh

sudo docker exec $docker_id /bin/bash $scripts_path/test-ports-nofeature.sh

# Don't install test feature and check REST for Oxygen, ODLPARENT-139 breaks it
if [ "$STREAM" == "fluorine" ] || [ "$STREAM" == "neon" ] || [ "$STREAM" == "sodium" ]; then
  sudo docker exec $docker_id /usr/bin/expect $scripts_path/test-karaf-oxygensafe.expect
else
  sudo docker exec $docker_id /usr/bin/expect $scripts_path/test-karaf.expect
  sudo docker exec $docker_id /bin/bash $scripts_path/test-rest-ok.sh
fi

sudo docker exec $docker_id /bin/bash $scripts_path/stop-odl.sh

sudo docker exec $docker_id /bin/bash $scripts_path/uninstall-rpm.sh

if [ "$SILO" == "sandbox" ]; then
  echo "Not uploading RPMs to Nexus because running in sandbox"
elif [ "$SILO" == "releng" ]; then
  RPM_NAME=$(sudo docker exec $docker_id find /root/rpmbuild/RPMS/noarch/ -wholename '*.rpm')
  SRPM_NAME=$(sudo docker exec $docker_id find /root/rpmbuild/SRPMS/ -wholename '*.rpm')
  UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
  mkdir -p "$UPLOAD_FILES_PATH"
  sudo docker cp $docker_id:$RPM_NAME "$_"
  sudo docker cp $docker_id:$SRPM_NAME "$_"
else
  echo "Unknown Jenkins silo: $SILO"
  exit 1
fi
