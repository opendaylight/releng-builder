
if [[ "$KARAF_VERSION" == "karaf3" ]]; then
    KARAF_ARTIFACT="distribution-karaf"
else
    KARAF_ARTIFACT="karaf"
fi

if [ "$JDKVERSION" == 'openjdk8' ]; then
    echo "Preparing for JRE Version 8"
    JAVA_HOME="/usr/lib/jvm/java-1.8.0"
elif [ "$JDKVERSION" == 'openjdk7' ]; then
    echo "Preparing for JRE Version 7"
    JAVA_HOME="/usr/lib/jvm/java-1.7.0"
fi

echo "Karaf artifact is ${KARAF_ARTIFACT"
echo "Java home is ${JAVA_HOME}"

cat > "${WORKSPACE}/set_variables.txt" <<EOF
JAVA_HOME="${JAVA_HOME}"
KARAF_ARTIFACT="${KARAF_ARTIFACT}"
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :
