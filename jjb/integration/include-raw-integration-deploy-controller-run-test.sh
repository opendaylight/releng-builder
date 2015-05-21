NEXUSURL_PREFIX=${ODLNEXUSPROXY:-https://nexus.opendaylight.org}
CONTROLLERMEM="2048m"

if [ ${CONTROLLERSCOPE} == 'all' ]; then
    ACTUALFEATURES="odl-integration-compatible-with-all,${CONTROLLERFEATURES}"
    CONTROLLERMEM="3072m"
else
    ACTUALFEATURES="${CONTROLLERFEATURES}"
fi

if [ ${BUNDLEURL} == 'last' ]; then
    NEXUSPATH="${NEXUSURL_PREFIX}/content/repositories/opendaylight.snapshot/org/opendaylight/integration/distribution-karaf"
    # Extract the BUNDLEVERSION from the pom.xml
    BUNDLEVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
    echo "Bundle version is ${BUNDLEVERSION}"
    # Acquire the timestamp information from maven-metadata.xml
    wget ${NEXUSPATH}/${BUNDLEVERSION}/maven-metadata.xml
    TIMESTAMP=`xpath maven-metadata.xml "//snapshotVersion[extension='zip'][1]/value/text()" 2>/dev/null`
    echo "Nexus timestamp is ${TIMESTAMP}"
    BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
    BUNDLE="distribution-karaf-${TIMESTAMP}.zip"
    ACTUALBUNDLEURL="${NEXUSPATH}/${BUNDLEVERSION}/${BUNDLE}"
else
    ACTUALBUNDLEURL="${BUNDLEURL}"
    BUNDLE="${BUNDLEURL##*/}"
    BUNDLEVERSION="$(basename $(dirname $BUNDLEURL))"
    BUNDLEFOLDER="distribution-karaf-${BUNDLEVERSION}"
fi

echo "Distribution bundle URL is ${ACTUALBUNDLEURL}"
echo "Distribution bundle is ${BUNDLE}"
echo "Distribution bundle version is ${BUNDLEVERSION}"
echo "Distribution folder is ${BUNDLEFOLDER}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"

action_tmpfile="${WORKSPACE}/action.sh"
# The following script is special, it replaces 3 veariables.
cat > "${action_tmpfile}" <<EOF

echo "Changing to /tmp"
cd /tmp

echo "Downloading the distribution..."
wget --no-verbose '${ACTUALBUNDLEURL}'

echo "Extracting the new controller..."
unzip -q ${BUNDLE}

echo "Configuring the startup features..."
FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" \${FEATURESCONF}
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" \${FEATURESCONF}
cat \${FEATURESCONF}

echo "Configuring the log..."
LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' \${LOGCONF}
cat \${LOGCONF}

echo "Configure max memory..."
MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' \${MEMCONF}
cat \${MEMCONF}

EOF
# TODO: Maybe move to max-memory.template.sh and configure-log.template.sh?
#       But that would mean we need more replacements to happen, making me think about using Python string.Template

scp "${action_tmpfile}" "${CONTROLLER0}:/tmp"
ssh ${CONTROLLER0} 'bash /tmp/action.sh'

# The following scripts replace only one variable.
# BEWARE: The only other replacement is \$ -> $, so do not nest bash variables to string internally!
actionlist="${ACTIONSBEFORE},start-controller,${ACTIONSAFTER}"
IFS=','  # for the following for to know where to split
for action in ${actionlist}  # Do not place the list to quotes, IFS would not work then.
do
    # Be defensive against path hacks.
    action_basename="${action##*/}"
    action_extensionless="${action_basename%%.*}"
    # If we ended up with empty string, it is not a valid action name.
    # This may happen if some ACTIONS list is empty.
    if [ "${#action_extensionless}" == "0" ]; then
        continue
    fi
    # This next part relies on current working directory being the one where this file is located.
    action_path="actions/${action_extensionless}.template.sh"
    # The two substitutions using pipelined sed commands. May fail the whole job if file fails to read.
    cat "${action_path}" | sed -e "s/\${BUNDLEFOLDER}/${BUNDLEFOLDER}/g" | sed -e 's/\\\$/\$/g' > "${action_tmpfile}"
    echo "Script template ${action_path} has lead to the following script:"
    cat "${action_tmpfile}"
    scp "${action_tmpfile}" "${CONTROLLER0}:/tmp"
    ssh ${CONTROLLER0} 'bash -exu "/tmp/action.sh"'
done

echo "Changing the testplan path..."
cat ${WORKSPACE}/test/csit/testplans/${TESTPLAN} | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v CONTROLLER:${CONTROLLER0} \
-v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Fetching Karaf log"
scp ${CONTROLLER0}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log .

# vim: ts=4 sw=4 sts=4 et ft=sh :

