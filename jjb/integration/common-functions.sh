#!/bin/bash

function set_java_vars() {
    # Setup JAVA_HOME and MAX_MEM Value in ODL startup config file

    echo "Configure java home and max memory..."
    sed -ie 's%^# export JAVA_HOME%export JAVA_HOME="\${JAVA_HOME:-${JAVA_HOME}}"%g' ${MEMCONF}
    sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM="${CONTROLLERMEM}"/g' ${MEMCONF}
    cat ${MEMCONF}

    echo "Set Java version"
    sudo /usr/sbin/alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
    sudo /usr/sbin/alternatives --set java ${JAVA_HOME}/bin/java
    echo "JDK default version ..."
    java -version

    echo "Set JAVA_HOME"
    export JAVA_HOME="${JAVA_HOME}"
    # Did you know that in HERE documents, single quote is an ordinary character, but backticks are still executing?
    JAVA_RESOLVED=\`readlink -e "\${JAVA_HOME}/bin/java"\`
    echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"
} # set_java_vars()
