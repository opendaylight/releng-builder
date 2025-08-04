#!/bin/bash
#@IgnoreInspection BashAddShebang
if [ "${IS_KARAF_APPL}" = "True" ] ; then
    echo "Karaf Deployments, Tests must have already run"
    exit
fi
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
. "${ROBOT_VENV}/bin/activate"
source /tmp/common-functions.sh "${BUNDLEFOLDER}" "${DISTROSTREAM}"
echo "#################################################"
echo "## invoke Tests for non-karaf Controllers      ##"
echo "#################################################"


# shellcheck disable=SC2034
nodes_list=$(get_nodes_list)

add_jvm_support

if [ "${NUM_OPENSTACK_SYSTEM}" -gt 0 ]; then
   echo "Exiting without running tests to deploy openstack for testing"
   exit
fi

echo "Generating mininet variables..."
for i in $(seq 1 "${NUM_TOOLS_SYSTEM}")
do
    MININETIP="TOOLS_SYSTEM_${i}_IP"
    tools_variables=${tools_variables}" -v ${MININETIP}:${!MININETIP}"
done

get_test_suites SUITES

echo "Starting Robot test suites ${SUITES} ..."
# ${TESTOPTIONS}, ${SUITES} are space-separated parameters and should not be quoted.
# shellcheck disable=SC2086
robot -N "${TESTPLAN}" \
      --removekeywords wuks -e exclude -e "skip_if_${DISTROSTREAM}" \
      -v BUNDLEFOLDER:"${BUNDLEFOLDER}" \
      -v BUNDLE_URL:"${ACTUAL_BUNDLE_URL}" \
      -v CONTROLLER:"${ODL_SYSTEM_IP}" \
      -v CONTROLLER_USER:"${USER}" \
      -v GERRIT_BRANCH:"${GERRIT_BRANCH}" \
      -v GERRIT_PROJECT:"${GERRIT_PROJECT}" \
      -v GERRIT_REFSPEC:"${GERRIT_REFSPEC}" \
      -v JAVA_HOME:"${JAVA_HOME}" \
      -v JDKVERSION:"${JDKVERSION}" \
      -v JENKINS_WORKSPACE:"${WORKSPACE}" \
      -v MININET1:"${TOOLS_SYSTEM_2_IP}" \
      -v MININET2:"${TOOLS_SYSTEM_3_IP}" \
      -v MININET3:"${TOOLS_SYSTEM_4_IP}" \
      -v MININET4:"${TOOLS_SYSTEM_5_IP}" \
      -v MININET5:"${TOOLS_SYSTEM_6_IP}" \
      -v MININET:"${TOOLS_SYSTEM_IP}" \
      -v MININET_USER:"${USER}" \
      -v NEXUSURL_PREFIX:"${NEXUSURL_PREFIX}" \
      -v NUM_ODL_SYSTEM:"${NUM_ODL_SYSTEM}" \
      -v NUM_TOOLS_SYSTEM:"${NUM_TOOLS_SYSTEM}" \
      -v ODL_STREAM:"${DISTROSTREAM}" \
      -v ODL_SYSTEM_1_IP:"${ODL_SYSTEM_IP}" \
      -v ODL_SYSTEM_IP:"${ODL_SYSTEM_IP}" \
      -v ODL_SYSTEM_USER:"${USER}" \
      -v SUITES:"${SUITES}" \
      -v TOOLS_SYSTEM_IP:"${TOOLS_SYSTEM_IP}" ${tools_variables} \
      -v TOOLS_SYSTEM_USER:"${USER}" \
      -v USER_HOME:"${HOME}" \
      -v IS_KARAF_APPL:"${IS_KARAF_APPL}" \
      -v WORKSPACE:/tmp \
      ${TESTOPTIONS} ${SUITES} || true

echo "Examining the files in data/log and checking filesize"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_IP}" "ls -altr /tmp/"
# shellcheck disable=SC2029
ssh "${ODL_SYSTEM_IP}" "du -hs /tmp/"

for i in $(seq 1 "${NUM_ODL_SYSTEM}")
do
    CONTROLLERIP="ODL_SYSTEM_${i}_IP"
    echo "Let's take the karaf thread dump again..."
    ssh "${!CONTROLLERIP}" "sudo ps aux" > "${WORKSPACE}"/ps_after.log
    pid=$(grep org.opendaylight.netconf.micro.NetconfMain "${WORKSPACE}/ps_after.log" | grep -v grep | tr -s ' ' | cut -f2 -d' ')
    echo "karaf main: org.apache.karaf.main.Main, pid:${pid}"
    # shellcheck disable=SC2029
    ssh "${!CONTROLLERIP}" "${JAVA_HOME}/bin/jstack -l ${pid}" > "${WORKSPACE}/karaf_${i}_${pid}_threads_after.log" || true
    echo "Killing ODL"
    set +e  # We do not want to create red dot just because something went wrong while fetching logs.
    ssh "${!CONTROLLERIP}" bash -c 'ps axf | grep org.opendaylight.netconf.micro.NetconfMain | grep -v grep | awk '"'"'{print "kill -9 " $1}'"'"' | sh'
done

sleep 5
# FIXME: Unify the copy process between various scripts.
# TODO: Use rsync.
for i in $(seq 1 "${NUM_ODL_SYSTEM}")
do
    CONTROLLERIP="ODL_SYSTEM_${i}_IP"
    echo "Compressing karaf.log ${i}"
    ssh "${!CONTROLLERIP}" gzip --best "/tmp/odlmicro_netconf.log"
    echo "Fetching compressed karaf.log ${i}"
    scp "${!CONTROLLERIP}:/tmp/odlmicro_netconf.log.gz" "odlmicro${i}.log.gz"
done

echo "Examine copied files"
ls -lt

true  # perhaps Jenkins is testing last exit code

# vim: ts=4 sw=4 sts=4 et ft=sh :
