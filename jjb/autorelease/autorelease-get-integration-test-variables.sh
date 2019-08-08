#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015, 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# ODLNEXUSPROXY is used to define the location of the Nexus server used by the CI system.
# by default it should be set to https://nexus.opendaylight.org
# in cases where an internal ci system is using multiple NEXUS systems one for artifacts and another for staging,
# we can override using ODLNEXUS_STAGING_URL to route the staging build to the 2nd server.
# (most CI setups where a single Nexus server is used, ODLNEXUS_STAGING_URL should be left unset)
NEXUS_STAGING_URL="${ODLNEXUS_STAGING_URL:-$ODLNEXUSPROXY}"

NEXUSURL="${NEXUS_STAGING_URL}/content/repositories/"
VERSION=$(grep -m2 '<version>' "${WORKSPACE}/integration/distribution/${KARAF_ARTIFACT}/pom.xml" | tail -n1 | awk -F'[<|>]' '/version/ { printf $3 }')
echo "VERSION: ${VERSION}"
STAGING_REPO_ID=$(grep "$NEXUS_STAGING_URL" "$WORKSPACE/archives/staging-repo.txt" | awk '{print $1}')
BUNDLE_URL="${NEXUSURL}/${STAGING_REPO_ID}/org/opendaylight/integration/${KARAF_ARTIFACT}/${VERSION}/${KARAF_ARTIFACT}-${VERSION}.zip"
# shellcheck disable=SC2129
echo STAGING_REPO_ID="$STAGING_REPO_ID" >> "$WORKSPACE/variables.prop"
echo BUNDLE_URL="$BUNDLE_URL" >> "$WORKSPACE/variables.prop"
echo KARAF_VERSION="$KARAF_VERSION" >> "$WORKSPACE/variables.prop"
echo "BUNDLE_URL: ${BUNDLE_URL}"

# Copy variables.prop to variables.jenkins-trigger so that the end of build
# trigger can pick up the file as input for triggering downstream jobs.
# This allows variables.prop to get archive to logs.opendaylight.org while not
# breaking the downstream trigger due to missing file from archiving.
cp variables.prop variables.jenkins-trigger
