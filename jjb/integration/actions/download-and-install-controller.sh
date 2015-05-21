
# Note, this feature is currently (unconditionally) run before any other action.

echo "Changing to /tmp"
cd /tmp

# TODO: This can be broken down to 5 actions, but is it worth to bloat ACTIONSBEFORE list? Decide.

echo "Downloading the distribution..."
wget --no-verbose "${ACTUALBUNDLEURL}"

echo "Extracting the new controller..."
unzip -q "${BUNDLE}"

echo "Configuring the startup features..."
FEATURESCONF="/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg"
sed -ie "s/featuresBoot=.*/featuresBoot=config,standard,region,package,kar,ssh,management,${ACTUALFEATURES}/g" "${FEATURESCONF}"
sed -ie "s%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features%mvn:org.opendaylight.integration/features-integration-index/${BUNDLEVERSION}/xml/features,mvn:org.opendaylight.integration/features-integration-test/${BUNDLEVERSION}/xml/features%g" "${FEATURESCONF}"
cat "${FEATURESCONF}"

echo "Configuring the log..."
LOGCONF="/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg"
sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=20MB/g' "${LOGCONF}"
cat "${LOGCONF}"

echo "Configure max memory..."
MEMCONF="/tmp/${BUNDLEFOLDER}/bin/setenv"
# The quotes in regexp have to be in single quotes, but variable to expand has to be out of single quotes.
sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="'"${CONTROLLERMEM}"'"/g' ${MEMCONF}
cat "${MEMCONF}"
