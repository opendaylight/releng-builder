#!/bin/sh

if [ "$KARAF_VERSION" = "odl" ]; then
    KARAF_ARTIFACT="opendaylight"
    KARAF_PROJECT="integration"
elif [ "$KARAF_VERSION" = "karaf3" ]; then
    KARAF_ARTIFACT="distribution-karaf"
    KARAF_PROJECT="integration"
elif [ "$KARAF_VERSION" = "controller" ]; then
    KARAF_ARTIFACT="controller-test-karaf"
    KARAF_PROJECT="controller"
elif [ "$KARAF_VERSION" = "netconf" ]; then
    KARAF_ARTIFACT="netconf-karaf"
    KARAF_PROJECT="netconf"
elif [ "$KARAF_VERSION" = "bgpcep" ]; then
    KARAF_ARTIFACT="bgpcep-karaf"
    KARAF_PROJECT="bgpcep"
else
    KARAF_ARTIFACT="karaf"
    KARAF_PROJECT="integration"
fi

if [ "$JDKVERSION" = 'openjdk17' ]; then
    echo "Preparing for JRE Version 17"
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
elif [ "$JDKVERSION" = 'openjdk11' ]; then
    echo "Preparing for JRE Version 11"
    JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
elif [ "$JDKVERSION" = 'openjdk8' ]; then
    echo "Preparing for JRE Version 8"
    JAVA_HOME="/usr/lib/jvm/java-1.8.0"
fi

echo "Karaf artifact is ${KARAF_ARTIFACT}"
echo "Karaf project is ${KARAF_PROJECT}"
echo "Java home is ${JAVA_HOME}"

# The following is not a shell file, double quotes would be literal.
cat > "${WORKSPACE}/set_variables.env" <<EOF
JAVA_HOME=${JAVA_HOME}
KARAF_ARTIFACT=${KARAF_ARTIFACT}
KARAF_PROJECT=${KARAF_PROJECT}
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :
