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

scripts_path=/builder/jjb/packaging

# A docker container must have been created by the build script
docker_id=$(sudo docker ps -qf name=build_rpm_suse)

sudo docker exec $docker_id /bin/bash $scripts_path/test-rpm-deps.sh

sudo docker exec $docker_id /bin/bash $scripts_path/install-rpm.sh

sudo docker exec $docker_id /bin/bash $scripts_path/start-odl.sh

sudo docker exec $docker_id /bin/bash $scripts_path/test-ports-nofeature.sh

sudo docker exec $docker_id /usr/bin/expect $scripts_path/test-karaf-opensuse-42.expect

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
