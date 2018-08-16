#!/bin/bash
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck source=${ROBOT_VENV}/bin/activate disable=SC1091
source ${ROBOT_VENV}/bin/activate
source /tmp/common-functions.sh ${BUNDLEFOLDER}
# Ensure we fail the job if any steps fail.
set -ex -o pipefail
totaltmr=$(timer)
get_os_deploy

PYTHON="${ROBOT_VENV}/bin/python"

# Use the testplan if specific SUITES are not defined.
if [ -z "${SUITES}" ]; then
    SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`
else
    newsuites=""
    workpath="${WORKSPACE}/test/csit/suites"
    for suite in ${SUITES}; do
        fullsuite="${workpath}/${suite}"
        if [ -z "${newsuites}" ]; then
            newsuites+=${fullsuite}
        else
            newsuites+=" "${fullsuite}
        fi
    done
    SUITES=${newsuites}
fi

sudo pip install -U python-openstackclient

USER=heat-admin
openstack object save OPNFV-APEX-SNAPSHOTS overcloudrc
source overcloudrc
cat overcloudrc
env
openstack hypervisor list

echo "Starting Robot test suites ${SUITES} ..."
# please add pybot -v arguments on a single line and alphabetized
suite_num=0
for suite in ${SUITES}; do
    # prepend an incremental counter to the suite name so that the full robot log combining all the suites as is done
    # in the rebot step below will list all the suites in chronological order as rebot seems to alphabetize them
    let "suite_num = suite_num + 1"
    suite_index="$(printf %02d ${suite_num})"
    suite_name="$(basename ${suite} | cut -d. -f1)"
    log_name="${suite_index}_${suite_name}"
    pybot -N ${log_name} \
    -c critical -e exclude -e skip_if_${DISTROSTREAM} \
    --log log_${log_name}.html --report report_${log_name}.html --output output_${log_name}.xml \
    --removekeywords wuks \
    --removekeywords name:SetupUtils.Setup_Utils_For_Setup_And_Teardown \
    --removekeywords name:SetupUtils.Setup_Test_With_Logging_And_Without_Fast_Failing \
    --removekeywords name:OpenStackOperations.Add_OVS_Logging_On_All_OpenStack_Nodes \
    -v BUNDLEFOLDER:${BUNDLEFOLDER} \
    -v BUNDLE_URL:${ACTUAL_BUNDLE_URL} \
    -v CMP_INSTANCES_SHARED_PATH:/var/instances \
    -v CONTROLLERFEATURES:"${CONTROLLERFEATURES}" \
    -v CONTROLLER_USER:${USER} \
    -v DEFAULT_LINUX_PROMPT:\$ \
    -v DEFAULT_LINUX_PROMPT_STRICT:]\$ \
    -v DEFAULT_USER:${USER} \
    -v ENABLE_ITM_DIRECT_TUNNELS:${ENABLE_ITM_DIRECT_TUNNELS} \
    -v HA_PROXY_IP:$ODL_SYSTEM_IP \
    -v JDKVERSION:${JDKVERSION} \
    -v JENKINS_WORKSPACE:${WORKSPACE} \
    -v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} \
    -v NUM_ODL_SYSTEM:${NUM_ODL_SYSTEM} \
    -v NUM_OS_SYSTEM:${NUM_OPENSTACK_SYSTEM} \
    -v NUM_TOOLS_SYSTEM:${NUM_TOOLS_SYSTEM} \
    -v ODL_SNAT_MODE:${ODL_SNAT_MODE} \
    -v ODL_STREAM:${DISTROSTREAM} \
    -v ODL_SYSTEM_IP:${ODL_SYSTEM_IP} \
    -v ODL_SYSTEM_1_IP:${ODL_SYSTEM_1_IP} \
    -v OS_CONTROL_NODE_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OS_CONTROL_NODE_1_IP:${OPENSTACK_CONTROL_NODE_1_IP} \
    -v OPENSTACK_BRANCH:${OPENSTACK_BRANCH} \
    -v OS_COMPUTE_1_IP:${OPENSTACK_COMPUTE_NODE_1_IP} \
    -v OS_COMPUTE_2_IP:${OPENSTACK_COMPUTE_NODE_2_IP} \
    -v OPENSTACK_TOPO:${OPENSTACK_TOPO} \
    -v OS_USER:${USER} \
    -v PUBLIC_PHYSICAL_NETWORK:${PUBLIC_PHYSICAL_NETWORK} \
    -v SECURITY_GROUP_MODE:${SECURITY_GROUP_MODE} \
    -v SSH_KEY:/tmp/id_rsa \
    -v USER_HOME:${HOME} \
    -v WORKSPACE:/tmp \
    ${TESTOPTIONS} ${suite} || true
done
#rebot exit codes seem to be different
rebot --output ${WORKSPACE}/output.xml --log log_full.html --report report.html -N openstack output_*.xml || true

echo "Examining the files in data/log and checking file size"
ssh ${ODL_SYSTEM_IP} "ls -altr /tmp/${BUNDLEFOLDER}/data/log/"
ssh ${ODL_SYSTEM_IP} "du -hs /tmp/${BUNDLEFOLDER}/data/log/*"

echo "Tests Executed"
printf "Total elapsed time: %s, stacking time: %s\n" "$(timer $totaltmr)" "${stacktime}"
true  # perhaps Jenkins is testing last exit code
# vim: ts=4 sw=4 sts=4 et ft=sh :
