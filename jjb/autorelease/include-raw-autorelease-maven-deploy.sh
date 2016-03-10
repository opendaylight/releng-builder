#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Job will pass in a variable ${DATESTAMP} if this variable is false than we
# we are likely releasing a release candidate. We should skip closing the
# Nexus staging repository so that we can sign the artifacts.
SKIP_STAGING_CLOSE=false
if [ "${DATESTAMP}" == "false" ]
then
    SKIP_STAGING_CLOSE=true
fi

# Assuming that mvn deploy created the hide/from/pom/files/m2repo directory.
cd hide/from/pom/files

mvn org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository \
    -DskipStagingRepositoryClose=${SKIP_STAGING_CLOSE} \
    -DrepositoryDirectory="`pwd`/m2repo" \
    -DnexusUrl=http://nexus.opendaylight.org/ \
    -DstagingProfileId="425e43800fea70" \
    -DserverId="opendaylight.staging" \
    -s $SETTINGS_FILE \
    -gs $GLOBAL_SETTINGS_FILE | tee $WORKSPACE/deploy-staged-repository.log
