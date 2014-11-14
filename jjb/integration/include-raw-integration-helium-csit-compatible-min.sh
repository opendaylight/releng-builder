# start Robot tests
pybot -c critical -e netconf -e pingall -e ovsdb -e apps -v TOPO_TREE_DEPTH:5 -v CONTROLLER:${CONTROLLER2} -v MININET:${MININET2} -v MININET_USER:${USER} -v USER_HOME:${JENKINS_HOME} -v RESTCONFPORT:8181 ${WORKSPACE}/test/csit/suites/karaf-compatible

# fetch controller log
BUNDLE="$(echo "$BUNDLEURL" | awk -F '/' '{ print $(NF) }')"
BUNDLEFOLDER="${BUNDLE//.zip}"
wget https://jenkins.opendaylight.org/integration/job/integration-deploy-controller-compatible-min/ws/${BUNDLEFOLDER}/data/log/karaf.log

