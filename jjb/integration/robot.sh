# start Robot tests
SUITES=${WORKSPACE}/test/csit/suites/${TEST_SUITE}
pybot -c critical -e netconf -e pingall -e ovsdb -e apps -v TOPO_TREE_DEPTH:5 -v CONTROLLER:${CONTROLLER0} -v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} -v RESTCONFPORT:8181 ${SUITES}

# fetch controller log
BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
BUNDLEFOLDER="${BUNDLE//.zip}"
scp $CONTROLLER0:/tmp/jenkins-integration-controller/$BUNDLEFOLDER/data/log/karaf.log .

# vim: ts=4 sw=4 sts=4 et ft=sh :
