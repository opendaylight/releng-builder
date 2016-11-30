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

# Assuming that mvn deploy created the hide/from/pom/files/stage directory.
cd hide/from/pom/files
mkdir -p m2repo/org/opendaylight/

ODLNEXUS_STAGING_URL=${ODLNEXUS_STAGING_URL:-$ODLNEXUSPROXY}
ODLNEXUS_STAGING_PROFILE=${ODLNEXUS_STAGING_PROFILE:-425e43800fea70}
ODLNEXUS_STAGING_SERVER_ID=${ODLNEXUS_STAGING_SERVER_ID:-"opendaylight.staging"}

rsync -avz --exclude 'maven-metadata*' \
           --exclude '_remote.repositories' \
           --exclude 'resolver-status.properties' \
           "stage/org/opendaylight" m2repo/org/

"$MVN" -V -B org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository \
    -DrepositoryDirectory="`pwd`/m2repo" \
    -DnexusUrl=$ODLNEXUS_STAGING_URL \
    -DstagingProfileId="$ODLNEXUS_STAGING_PROFILE" \
    -DserverId="$ODLNEXUS_STAGING_SERVER_ID" \
    -s $SETTINGS_FILE \
    -gs $GLOBAL_SETTINGS_FILE | tee $WORKSPACE/deploy-staged-repository.log
