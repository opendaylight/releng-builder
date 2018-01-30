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
    # shellcheck disable=SC2037
    JAVA_RESOLVED=\`readlink -e "\${JAVA_HOME}/bin/java"\`
    echo "Java binary pointed at by JAVA_HOME: \${JAVA_RESOLVED}"
} # set_java_vars()

# shellcheck disable=SC2034 foo appears unused. Verify it or export it.
function configure_karaf_log() {
    local logapi=log4j
    echo "Configuring the karaf log..."
    if [[ "$KARAF_VERSION" == "karaf4" ]]; then
        logapi=log4j2
        # FIXME: Make log size limit configurable from build parameter.
        echo "log4j2.appender.rolling.policies.size.size = 1GB" >> ${LOGCONF}
        echo "log4j2.logger.org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver = WARN" >> ${LOGCONF}
    else
        sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' ${LOGCONF}
        # FIXME: Make log size limit configurable from build parameter.
        sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=30GB/g' ${LOGCONF}
        echo "log4j.logger.org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver = WARN" >> ${LOGCONF}
    fi

    # Add custom logging levels
    # CONTROLLERDEBUGMAP is expected to be a key:value map of space separated values like "module:level module2:level2"
    # where module is abbreviated and does not include "org.opendaylight."
    unset IFS
    if [ -n "${CONTROLLERDEBUGMAP}" ]; then
        for kv in ${CONTROLLERDEBUGMAP}; do
            module="\${kv%%:*}"
            level="\${kv#*:}"
            if [ "\${module}" ] && [ "\${level}" ]; then
                echo "\${logapi}.logger.org.opendaylight.\${module} = \${level}" >> ${LOGCONF}
            fi
        done
    fi

    cat ${LOGCONF}
} # function configure_karaf_log()
