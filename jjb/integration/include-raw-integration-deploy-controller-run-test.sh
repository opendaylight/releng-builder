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

# Helper finction to add variable definition lines to a script file.
function add_variable_definition_to_file () {
    variable_name="$1"
    file_name="$2"
    eval "variable_value=\$${variable_name}"
    echo "${variable_name}=\"${variable_value}\"" >> "${file_name}"
}

# Reset script file to use.
scriptname="actions.sh"
action_tmpfile="${WORKSPACE}/${scriptname}"
echo "#!/bin/bash" > "${action_tmpfile}"

# Export variables, so that script running on controller machine knows them.
echo "Distribution bundle URL is ${ACTUALBUNDLEURL}"
add_variable_definition_to_file "ACTUALBUNDLEURL" "${action_tmpfile}"
echo "Final list of features to install is ${ACTUALFEATURES}"
add_variable_definition_to_file "ACTUALFEATURES" "${action_tmpfile}"
echo "Distribution bundle is ${BUNDLE}"
add_variable_definition_to_file "BUNDLE" "${action_tmpfile}"
echo "Distribution folder is ${BUNDLEFOLDER}"
add_variable_definition_to_file "BUNDLEFOLDER" "${action_tmpfile}"
echo "Distribution bundle version is ${BUNDLEVERSION}"
add_variable_definition_to_file "BUNDLEVERSION" "${action_tmpfile}"
echo "Amount of Java heap to use is ${CONTROLLERMEM}"
add_variable_definition_to_file "CONTROLLERMEM" "${action_tmpfile}"
echo "Nexus prefix is ${NEXUSURL_PREFIX}"
add_variable_definition_to_file "NEXUSURL_PREFIX" "${action_tmpfile}"

# Paste actions to the script file in order specified.
actionlist="download-and-install-controller,${ACTIONSBEFORE},start-controller,${ACTIONSAFTER}"
IFS_backup="${IFS}"
IFS=','  # for the following "for" to know where to split
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
    action_path="actions/${action_extensionless}.sh"
    # The paste operation. May fail the whole job if file fails to read.
    cat "${action_path}" >> "${action_tmpfile}"
done
IFS="${IFS_backup}"  # Otherwise pybot does not distinguish paths, for example.
scp "${action_tmpfile}" "${CONTROLLER0}:/tmp"
# No cat to log contents, we rely on -x flag of bash to make execution readable.
ssh ${CONTROLLER0} bash -exu "/tmp/${scriptname}"

echo "Changing the testplan path..."
cat "${WORKSPACE}/test/csit/testplans/${TESTPLAN}" | sed "s:integration:${WORKSPACE}:" > testplan.txt
cat testplan.txt

SUITES=`egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' testplan.txt | tr '\012' ' '`

echo "Starting Robot test suites ${SUITES} ..."
pybot -N ${TESTPLAN} -c critical -e exclude -v BUNDLEFOLDER:${BUNDLEFOLDER} -v WORKSPACE:/tmp \
-v NEXUSURL_PREFIX:${NEXUSURL_PREFIX} -v CONTROLLER:${CONTROLLER0} \
-v MININET:${MININET0} -v MININET_USER:${USER} -v USER_HOME:${HOME} ${TESTOPTIONS} ${SUITES} || true

echo "Fetching Karaf log"
scp "${CONTROLLER0}:/tmp/${BUNDLEFOLDER}/data/log/karaf.log" .

# vim: ts=4 sw=4 sts=4 et ft=sh :
