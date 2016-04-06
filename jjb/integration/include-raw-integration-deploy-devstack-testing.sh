echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=$( egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' ' )

echo "Starting Robot test suites ${SUITES} ..."

pybot -e exclude \
-v WORKSPACE:/tmp -v USER_HOME:$HOME -L TRACE \
-v DEVSTACK_SYSTEM_USER:$USER \
-v DEVSTACK_SYSTEM_IP:$ODL_SYSTEM_IP \
-v DEFAULT_LINUX_PROMPT:\]\> \
-v OPENSTACK_BRANCH:$OPENSTACK_BRANCH \
-v ODL_VERSION:$ODL_VERSION \
-v TEMPEST_REGEX:$TEMPEST_REGEX ${SUITES} || true

scp $ODL_SYSTEM_IP:/opt/stack/logs/devstacklog.txt $WORKSPACE/
scp -r $ODL_SYSTEM_IP:/opt/stack/logs/*karaf* $WORKSPACE/

# vim: ts=4 sw=4 sts=4 et ft=sh :

