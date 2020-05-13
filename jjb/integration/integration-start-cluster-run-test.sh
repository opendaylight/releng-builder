#!/bin/bash
#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source "${ROBOT_VENV}/bin/activate"
source /tmp/common-functions.sh "${BUNDLEFOLDER}"
# Ensure we fail the job if any steps fail.
set -ex -o pipefail

echo "#################################################"
echo "##         Verify Cluster is UP                ##"
echo "#################################################"

create_post_startup_script

copy_and_run_post_startup_script

dump_controller_threads

if [ "${NUM_OPENSTACK_SYSTEM}" -gt 0 ]; then
   echo "Exiting without running tests to deploy openstack for testing"
   exit
fi

echo "Generating controller variables..."
for i in $(seq 1 "${NUM_ODL_SYSTEM}")
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    odl_variables=${odl_variables}" -v ${CONTROLLERIP}:${!CONTROLLERIP}"
done

echo "Generating mininet variables..."
for i in $(seq 1 "${NUM_TOOLS_SYSTEM}")
do
    MININETIP=TOOLS_SYSTEM_${i}_IP
    tools_variables=${tools_variables}" -v ${MININETIP}:${!MININETIP}"
done

get_test_suites SUITES

echo "Starting Robot test suites ${SUITES} ..."
# ${TESTOPTIONS}, ${SUITES} are space-separated parameters and should not be quoted.
# shellcheck disable=SC2086
robot -N "${TESTPLAN}" \
      --removekeywords wuks -c critical -e exclude -e "skip_if_${DISTROSTREAM}" \
      -v BUNDLEFOLDER:"${BUNDLEFOLDER}" \
      -v BUNDLE_URL:"${ACTUAL_BUNDLE_URL}" \
      -v CONTROLLER:"${ODL_SYSTEM_IP}" \
      -v CONTROLLER1:"${ODL_SYSTEM_2_IP}" \
      -v CONTROLLER2:"${ODL_SYSTEM_3_IP}" \
      -v CONTROLLER_USER:"${USER}" \
      -v JAVA_HOME:"${JAVA_HOME}" \
      -v JDKVERSION:"${JDKVERSION}" \
      -v JENKINS_WORKSPACE:"${WORKSPACE}" \
      -v MININET:"${TOOLS_SYSTEM_IP}" \
      -v MININET1:"${TOOLS_SYSTEM_2_IP}" \
      -v MININET2:"${TOOLS_SYSTEM_3_IP}" \
      -v MININET_USER:"${USER}" \
      -v NEXUSURL_PREFIX:"${NEXUSURL_PREFIX}" \
      -v NUM_ODL_SYSTEM:"${NUM_ODL_SYSTEM}" \
      -v NUM_TOOLS_SYSTEM:"${NUM_TOOLS_SYSTEM}" \
      -v ODL_STREAM:"${DISTROSTREAM}" \
      -v ODL_SYSTEM_IP:"${ODL_SYSTEM_IP}" ${odl_variables} \
      -v ODL_SYSTEM_USER:"${USER}" \
      -v TOOLS_SYSTEM_IP:"${TOOLS_SYSTEM_IP}" ${tools_variables} \
      -v TOOLS_SYSTEM_USER:"${USER}" \
      -v USER_HOME:"${HOME}" \
      -v WORKSPACE:/tmp \
      ${TESTOPTIONS} ${SUITES} || true



echo "Examining the files in data/log and checking filesize"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_1_IP}" "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_1_IP}" "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_2_IP}" "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_2_IP}" "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_3_IP}" "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_3_IP}" "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

set +e  # We do not want to create red dot just because something went wrong while fetching logs.
for i in $(seq 1 "${NUM_ODL_SYSTEM}")
do
    CONTROLLERIP="ODL_SYSTEM_${i}_IP"
    echo "Let's take the karaf thread dump again"
    ssh "${!CONTROLLERIP}" "sudo ps aux" > "${WORKSPACE}/ps_after.log"
    pid=$(grep org.apache.karaf.main.Main "${WORKSPACE}/ps_after.log" | grep -v grep | tr -s ' ' | cut -f2 -d' ')
    echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
    # shellcheck disable=SC2029
    ssh "${!CONTROLLERIP}" "${JAVA_HOME}/bin/jstack -l ${pid}" > "${WORKSPACE}/karaf_${i}_${pid}_threads_after.log" || true
    echo "killing karaf process..."
    ssh "${!CONTROLLERIP}" bash -c 'ps axf | grep karaf | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done
sleep 5
for i in $(seq 1 "${NUM_ODL_SYSTEM}")
do
    CONTROLLERIP=ODL_SYSTEM_${i}_IP
    echo "Compressing karaf.log ${i}"
    ssh "${!CONTROLLERIP}" gzip --best "/tmp/${BUNDLEFOLDER}/data/log/karaf.log"
    echo "Fetching compressed karaf.log ${i}"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz" "odl${i}_karaf.log.gz" && ssh "${!CONTROLLERIP}" rm -f "/tmp/${BUNDLEFOLDER}/data/log/karaf.log.gz"
    # TODO: Should we compress the output log file as well?
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log" "odl${i}_karaf_console.log" && ssh "${!CONTROLLERIP}" rm -f "/tmp/${BUNDLEFOLDER}/data/log/karaf_console.log"
    echo "Fetch GC logs"
    # FIXME: Put member index in filename, instead of directory name.
    mkdir -p "gclogs-${i}"
    scp "${!CONTROLLERIP}:/tmp/${BUNDLEFOLDER}/data/log/*.log" "gclogs-${i}/" && ssh "${!CONTROLLERIP}" rm -f "/tmp/${BUNDLEFOLDER}/data/log/*.log"
done

echo "Examine copied files"
ls -lt

true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :
