#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Assuming that mvn deploy created the hide/from/pom/files/stage directory.
cd hide/from/pom/files || exit 1
mkdir -p m2repo/org/opendaylight/

rsync -avz --exclude 'maven-metadata*' \
           --exclude '_remote.repositories' \
           --exclude 'resolver-status.properties' \
           "stage/org/opendaylight/$PROJECT" m2repo/org/opendaylight/

mvn org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository \
    -DrepositoryDirectory="$(pwd)/m2repo" \
    -DnexusUrl=https://nexus.opendaylight.org/ \
    -DstagingProfileId="$STAGING_PROFILE_ID" \
    -DserverId="opendaylight-staging" \
    -s "$SETTINGS_FILE" \
    -gs "$GLOBAL_SETTINGS_FILE" | tee "$WORKSPACE/deploy-staged-repository.log"
