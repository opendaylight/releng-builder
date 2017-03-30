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
cd hide/from/pom/files || exit 1
mkdir -p m2repo/org/opendaylight/

# ODLNEXUSPROXY is used to define the location of the Nexus server used by the CI system.
# by default it should be set to https://nexus.opendaylight.org
# in cases where an internal ci system is using multiple NEXUS systems one for artifacts and another for staging,
# we can override using ODLNEXUS_STAGING_URL to route the staging build to the 2nd server.
# (most CI setups where a single Nexus server is used, ODLNEXUS_STAGING_URL should be left unset)
NEXUS_STAGING_URL=${ODLNEXUS_STAGING_URL:-"http://10.29.8.46:8081"}
NEXUS_STAGING_PROFILE=${ODLNEXUS_STAGING_PROFILE:-425e43800fea70}
NEXUS_STAGING_SERVER_ID=${ODLNEXUS_STAGING_SERVER_ID:-"opendaylight.staging"}

rsync -avz --remove-source-files \
           --exclude 'maven-metadata*' \
           --exclude '_remote.repositories' \
           --exclude 'resolver-status.properties' \
           "stage/org/opendaylight" m2repo/org/

"$MVN" org.sonatype.plugins:nexus-staging-maven-plugin:1.6.8:deploy-staged-repository \
    -DrepositoryDirectory="$(pwd)/m2repo" \
    -DnexusUrl="$NEXUS_STAGING_URL" \
    -DstagingProfileId="$NEXUS_STAGING_PROFILE" \
    -DserverId="$NEXUS_STAGING_SERVER_ID" \
    -s "$SETTINGS_FILE" \
    -gs "$GLOBAL_SETTINGS_FILE" \
    {opendaylight-infra-mvn-opts} | tee "$WORKSPACE/deploy-staged-repository.log"
