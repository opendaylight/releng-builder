#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
source ${ROBOT_VENV}/bin/activate

echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."

pybot --removekeywords wuks -e exclude \
-v WORKSPACE:$WORKSPACE -v USER_HOME:$HOME -L TRACE \
-v DEVSTACK_SYSTEM_USER:$USER \
-v DEVSTACK_SYSTEM_IP:$OPENSTACK_CONTROL_NODE_IP \
-v DEFAULT_LINUX_PROMPT:\]\> \
-v OPENSTACK_BRANCH:$OPENSTACK_BRANCH \
-v ODL_VERSION:$ODL_VERSION \
-v DEVSTACK_DEPLOY_PATH:/opt/stack/new/devstack \
-v TEMPEST_REGEX:$TEMPEST_REGEX ${SUITES} || true

scp $OPENSTACK_CONTROL_NODE_IP:/opt/stack/logs/devstacklog.txt $WORKSPACE/
scp -r $OPENSTACK_CONTROL_NODE_IP:/opt/stack/logs/*karaf* $WORKSPACE/

# vim: ts=4 sw=4 sts=4 et ft=sh :

