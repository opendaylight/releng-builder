#!/bin/bash

echo "common-functions.sh is being sourced"

BUNDLEFOLDER=$1

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

function print_common_env() {
    cat << EOF
common-functions environment:
MAVENCONF: ${MAVENCONF}
FEATURESCONF: ${FEATURESCONF}
CUSTOMPROP: ${CUSTOMPROP}
LOGCONF: ${LOGCONF}
MEMCONF: ${MEMCONF}
CONTROLLERMEM: ${CONTROLLERMEM}
AKKACONF: ${AKKACONF}
MODULESCONF: ${MODULESCONF}
MODULESHARDSCONF: ${MODULESHARDSCONF}

EOF
}
print_common_env

# Setup JAVA_HOME and MAX_MEM Value in ODL startup config file
function set_java_vars() {
    local -r java_home=$1
    local -r controllermem=$2
    local -r memconf=$3

    echo "Configure\n    java home: ${java_home}\n    max memory: ${controllermem}\n    memconf: ${memconf}"

    sed -ie 's%^# export JAVA_HOME%export JAVA_HOME=${JAVA_HOME:-'"${java_home}"'}%g' ${memconf}
    sed -ie 's/JAVA_MAX_MEM="2048m"/JAVA_MAX_MEM='"${controllermem}"'/g' ${memconf}
    echo "cat ${memconf}"
    cat ${memconf}

    echo "Set Java version"
    sudo /usr/sbin/alternatives --install /usr/bin/java java ${java_home}/bin/java 1
    sudo /usr/sbin/alternatives --set java ${java_home}/bin/java
    echo "JDK default version ..."
    java -version

    echo "Set JAVA_HOME"
    export JAVA_HOME="${java_home}"
    # shellcheck disable=SC2037
    JAVA_RESOLVED=$(readlink -e "${java_home}/bin/java")
    echo "Java binary pointed at by JAVA_HOME: ${JAVA_RESOLVED}"
} # set_java_vars()

# shellcheck disable=SC2034
# foo appears unused. Verify it or export it.
function configure_karaf_log() {
    local -r karaf_version=$1
    local -r controllerdebugmap=$2
    local logapi=log4j

    # Check what the logging.cfg file is using for the logging api: log4j or log4j2
    grep "log4j2" ${LOGCONF}
    if [ $? -eq 0 ]; then
        logapi=log4j2
    fi

    echo "Configuring the karaf log... karaf_version: ${karaf_version}, logapi: ${logapi}"
    if [ "${logapi}" == "log4j2" ]; then
        # FIXME: Make log size limit configurable from build parameter.
        sed -ie 's/log4j2.appender.rolling.policies.size.size = 16MB/log4j2.appender.rolling.policies.size.size = 1GB/g' ${LOGCONF}
        orgmodule="org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver"
        orgmodule_="${orgmodule//./_}"
        echo "${logapi}.logger.${orgmodule_}.name = WARN" >> ${LOGCONF}
        echo "${logapi}.logger.${orgmodule_}.level = WARN" >> ${LOGCONF}
    else
        sed -ie 's/log4j.appender.out.maxBackupIndex=10/log4j.appender.out.maxBackupIndex=1/g' ${LOGCONF}
        # FIXME: Make log size limit configurable from build parameter.
        sed -ie 's/log4j.appender.out.maxFileSize=1MB/log4j.appender.out.maxFileSize=30GB/g' ${LOGCONF}
        echo "${logapi}.logger.org.opendaylight.yangtools.yang.parser.repo.YangTextSchemaContextResolver = WARN" >> ${LOGCONF}
    fi

    # Add custom logging levels
    # CONTROLLERDEBUGMAP is expected to be a key:value map of space separated values like "module:level module2:level2"
    # where module is abbreviated and does not include "org.opendaylight."
    unset IFS
    echo "controllerdebugmap: ${controllerdebugmap}"
    if [ -n "${controllerdebugmap}" ]; then
        for kv in ${controllerdebugmap}; do
            module="${kv%%:*}"
            level="${kv#*:}"
            echo "module: $module, level: $level"
            # shellcheck disable=SC2157
            if [ -n "${module}" ] && [ -n "${level}" ]; then
                orgmodule="org.opendaylight.${module}"
                if [ "${logapi}" == "log4j2" ]; then
                    orgmodule_="${orgmodule//./_}"
                    echo "${logapi}.logger.${orgmodule_}.name = ${orgmodule}" >> ${LOGCONF}
                    echo "${logapi}.logger.${orgmodule_}.level = ${level}" >> ${LOGCONF}
                else
                    echo "${logapi}.logger.${orgmodule} = ${level}" >> ${LOGCONF}
                fi
            fi
        done
    fi

    echo "cat ${LOGCONF}"
    cat ${LOGCONF}
} # function configure_karaf_log()

# convert commas in csv strings to spaces (ssv)
function csv2ssv() {
    local csv=$1
    if [ -n "${csv}" ]; then
        ssv=$(echo ${csv} | sed 's/,/ /g' | sed 's/\ \ */\ /g')
    fi

    echo "${ssv}"
} # csv2ssv
