CONTROLLERMEM="3072m"
ACTUALFEATURES="odl-integration-all"

echo "Kill any controller running"
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh

echo "Clean workspace"
rm -rf *

echo "Downloading the distribution..."
wget --progress=dot:mega "${ACTUAL_BUNDLE_URL}"

echo "Extracting the new controller..."
unzip -q "${BUNDLE}"

echo "Configuring the startup features..."
FEATURESCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg"
FEATURE_TEST_STRING="features-integration-test"
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    FEATURE_TEST_STRING="features-test"
fi

sed -ie "s%\(featuresRepositories=\|featuresRepositories =\)%featuresRepositories = mvn:org.opendaylight.integration/${FEATURE_TEST_STRING}/${BUNDLEVERSION}/xml/features,%g" ${FEATURESCONF}

# Feature is instaled later.
cat "${FEATURESCONF}"

echo "Configuring the log..."
LOGCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg"
# FIXME: Make log size limit configurable from build parameter.
if [[ "$KARAF_VERSION" == "karaf4" ]]; then
    echo "log4j2.appender.rolling.policies.size.size = 20MB" >> ${LOGCONF}
else
    sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' "${LOGCONF}"
fi
cat "${LOGCONF}"

echo "Configure the repos..."
REPOCONF="${WORKSPACE}/${BUNDLEFOLDER}/etc/org.ops4j.pax.url.mvn.cfg"
sed -ie '/http/d' "${REPOCONF}"
sed -ie '$s/...$//' "${REPOCONF}"
cat "${REPOCONF}"

echo "Configure max memory..."
MEMCONF="${WORKSPACE}/${BUNDLEFOLDER}/bin/setenv"
sed -ie "s/2048m/${CONTROLLERMEM}/g" "${MEMCONF}"
cat "${MEMCONF}"

if [ "${JDKVERSION}" == 'openjdk8' ]; then
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
echo "Default JDK Version, JAVA_HOME should override"
java -version

echo "Redirecting karaf console output to karaf_console.log"
export KARAF_REDIRECT="${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log"
mkdir -p ${WORKSPACE}/${BUNDLEFOLDER}/data/log

echo "Starting controller..."
${WORKSPACE}/${BUNDLEFOLDER}/bin/start

echo "Waiting for controller to come up..."
# Silence the chatty output during the loop.
set +x
COUNT=0
# Bug 9044 workaround: use bin/client instead of Linux ssh command.
CLIENT="${WORKSPACE}/${BUNDLEFOLDER}/bin/client"
while true; do
    # Is there a way to both print output and store RC without manipulating the e flag?
    set +e
    ${CLIENT} "feature:list -i"
    RC="$?"
    set -e
    if [[ "${RC}" == "0" ]]; then
        echo Karaf is UP
        break
    elif (( "${COUNT}" > 600 )); then
        echo Timeout Karaf DOWN
        echo "Dumping Karaf log..."
        cat "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log"
        echo "Listing all open ports on controller system"
        netstat -pnatu
        exit 1
    else
        echo "${RC}"
        COUNT=$(( ${COUNT} + 1 ))
        sleep 1
        if [[ $(($COUNT % 5)) == 0 ]]; then
            echo already waited ${COUNT} seconds...
        fi
    fi
done
# Un-silence the chatty output.
set -x

echo "Installing all features..."
$CLIENT feature:install ${ACTUALFEATURES} || echo $? > "${WORKSPACE}/error.txt"

echo "killing karaf process..."
ps axf | grep karaf | grep -v grep | awk '{print "kill -9 " $1}' | sh
sleep 5

echo "Fetching Karaf logs"
# TODO: Move instead of copy? Gzip?
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf.log" .
cp "${WORKSPACE}/${BUNDLEFOLDER}/data/log/karaf_console.log" .

echo "Exit if error"
if [ -f "${WORKSPACE}/error.txt" ]; then
    echo "Failed to deploy offline"
    exit 1
else
    echo "Offline test: PASS"
fi

# vim: ts=4 sw=4 sts=4 et ft=sh :
