#!/bin/bash

# Basic controller configuration settings
export MAVENCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.url.mvn.cfg
export FEATURESCONF=/tmp/${BUNDLEFOLDER}/etc/org.apache.karaf.features.cfg
export CUSTOMPROP=/tmp/${BUNDLEFOLDER}/etc/custom.properties
export LOGCONF=/tmp/${BUNDLEFOLDER}/etc/org.ops4j.pax.logging.cfg
export MEMCONF=/tmp/${BUNDLEFOLDER}/bin/setenv
export CONTROLLERMEM="2048m"

# Cluster specific configuration settings
export AKKACONF=/tmp/${BUNDLEFOLDER}/configuration/initial/akka.conf
export MODULESCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/modules.conf
export MODULESHARDSCONF=/tmp/${BUNDLEFOLDER}/configuration/initial/module-shards.conf

# Setup JAVA_HOME and MAX_MEM Value in ODL startup config file
function set_java_vars() {
    echo "Configure java home and max memory..."
    echo "MEMCONF: $1"
    echo "CONTROLLERMEM: $2"
    echo "JAVA_HOME: $3"
    export MEMCONF=$1
    export CONTROLLERMEM=$2
    export JAVA_HOME=$3
    sed -ie 's/^# export JAVA_HOME/export JAVA_HOME=${JAVA_HOME:-'"${JAVA_HOME}"'}/g' ${MEMCONF}
    sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM='"${CONTROLLERMEM}"'/g' ${MEMCONF}
    cat ${MEMCONF}

    echo "Set Java version"
    sudo /usr/sbin/alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
    sudo /usr/sbin/alternatives --set java ${JAVA_HOME}/bin/java
    echo "JDK default version ..."

    echo "Set JAVA_HOME"
    export JAVA_HOME="${JAVA_HOME}"
    # shellcheck disable=SC2037
    JAVA_RESOLVED=$(readlink -e "\${JAVA_HOME}/bin/java")
    echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"
} # set_java_vars()
