#!/bin/bash
if [[ -n "${CONTROLLERFEATURES}" ]]; then
    ACTUALFEATURES="odl-integration-all,${CONTROLLERFEATURES}"
else
    ACTUALFEATURES="odl-integration-all"
fi

if [[ "${JOB_NAME}" == *"distribution-sanity"* ]]; then
    CONTROLLERMEM="4096m"
else
    CONTROLLERMEM="3072m"
fi

echo "Kill any controller running"
# shellcheck disable=SC2009
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Clean Existing distribution"
rm -rf "${BUNDLEFOLDER}"

echo "Fetch the distribution..."
if  [[ -z "${BUNDLE_PATH}" ]]; then
    wget --progress=dot:mega  "${ACTUAL_BUNDLE_URL}"
else
    cp "${BUNDLE_PATH}" .
fi

echo "Extracting the new controller..."
unzip -q "${BUNDLE}"

echo "Configuring the startup features..."
FEATURESCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg"
FEATURE_TEST_STRING="features-test"
if [[ "$KARAF_VERSION" == "karaf3" ]]; then
    FEATURE_TEST_STRING="features-integration-test"
fi

sed -ie "s%\(featuresRepositories= \|featuresRepositories = \)%featuresRepositories = mvn:org.opendaylight.integration/${FEATURE_TEST_STRING}/${BUNDLE_VERSION}/xml/features,%g" "${FEATURESCONF}"

if [[ -n "${REPO_URL}" ]]; then
   # sed below will fail if it finds space between feature repos.
   REPO_URL_NO_SPACE="$(echo -e "${REPO_URL}" | tr -d '[:space:]')"
   sed -ie "s%featuresRepositories = %featuresRepositories = ${REPO_URL_NO_SPACE},%g" "${FEATURESCONF}"
fi

# Add actual boot features.
# sed below will fail if it finds space between feature repos.
FEATURES_NO_SPACE="$(echo -e "${ACTUALFEATURES}" | tr -d '[:space:]')"
sed -ie "s/\(featuresBoot= \|featuresBoot = \)/featuresBoot = ${FEATURES_NO_SPACE},/g" "${FEATURESCONF}"
cat "${FEATURESCONF}"

echo "Configuring the log..."
LOGCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg"
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' "${LOGCONF}"
cat "${LOGCONF}"

echo "Configure max memory..."
MEMCONF="${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv"
sed -ie "s/2048m/${CONTROLLERMEM}/g" "${MEMCONF}"
cat "${MEMCONF}"

echo "Listing all open ports on controller system"
netstat -pnatu

if [ "$JDKVERSION" == 'openjdk11' ]; then
    echo "Preparing for JRE Version 11"
    JAVA_HOME="/opt/jdk-11"
elif [ "${JDKVERSION}" == 'openjdk8' ]; then
    echo "Setting the JRE Version to 8"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.8.0-openjdk-1.8.0.60-2.b27.el7_1.x86_64/jre/bin/java
    export JAVA_HOME='/usr/lib/jvm/java-1.8.0'
elif [ "${JDKVERSION}" == 'openjdk7' ]; then
    echo "Setting the JRE Version to 7"
    # dynamic_verify does not allow sudo, JAVA_HOME should be enough for karaf start.
    # sudo /usr/sbin/alternatives --set java /usr/lib/jvm/java-1.7.0-openjdk-1.7.0.85-2.6.1.2.el7_1.x86_64/jre/bin/java
    export JAVA_HOME='/usr/lib/jvm/java-1.7.0'
fi
readlink -e "${JAVA_HOME}/bin/java"
echo "JDK Version should be overriden by JAVA_HOME"
java -version

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p "${WORKSPACE}/${BUNDLEFOLDER}/data/log"

echo "Starting controller..."
"${WORKSPACE}/${BUNDLEFOLDER}/bin/start"

function dump_log_and_exit {
    echo "Dumping first 500K bytes of karaf log..."
    head --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
    echo "Dumping last 500K bytes of karaf log..."
    tail --bytes=500K "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
    cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
    cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .
    exit 1
}

echo "Waiting up to 6 minutes for controller to come up, checking every 5 seconds..."
COUNT="0"
while true; do
    COUNT=$(( COUNT + 5 ))
    sleep 5
    echo "already waited ${COUNT} seconds..."
    if grep --quiet 'org.opendaylight.infrautils.*System ready' "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"; then
        echo "Controller is UP"
        break
    elif (( "${COUNT}" >= "360" )); then
        echo "Timeout Controller DOWN"
        dump_log_and_exit
    fi
done

# echo "Checking OSGi bundles..."
# sshpass seems to fail with new karaf version
# sshpass -p karaf ${WORKSPACE}/${BUNDLEFOLDER}/bin/client -u karaf 'bundle:list'

echo "Listing all open ports on controller system"
netstat -pnatu

function exit_on_log_file_message {
    echo "looking for \"$1\" in karaf.log file"
    if grep --quiet "$1" "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"; then
        echo ABORTING: found "$1"
        dump_log_and_exit
    fi

    echo "looking for \"$1\" in karaf_console.log file"
    if grep --quiet "$1" "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"; then
        echo ABORTING: found "$1"
        dump_log_and_exit
    fi
}

exit_on_log_file_message 'Error installing boot feature repository'
exit_on_log_file_message 'BindException: Address already in use'
exit_on_log_file_message 'server is unhealthy'

echo "Fetching Karaf logs"
# TODO: Move instead of copy? Gzip?
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .

echo "Kill controller"
# shellcheck disable=SC2009
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Bug 4628: Detecting misplaced config files"
pushd "${WORKSPACE}/${BUNDLEFOLDER}" || exit
XMLS_FOUND="$(echo -- *.xml)"
popd || exit
if [ "$XMLS_FOUND" != "*.xml" ]; then
    echo "Bug 4628 confirmed."
    ## TODO: Uncomment the following when ODL is fixed, to guard against regression.
    # exit 1
else
    echo "Bug 4628 not detected."
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :
