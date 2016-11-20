#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015, 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
[ "$ODLNEXUSPROXY" ] || ODLNEXUSPROXY="https://logs.opendaylight.org"

NEXUSURL=${ODLNEXUSPROXY}/content/repositories/
VERSION=`grep -m2 '<version>' ${WORKSPACE}/integration/distribution/distribution-karaf/pom.xml | tail -n1 | awk -F'[<|>]' '/version/ { printf $3 }'`
echo "VERSION: ${VERSION}"
REPOID=`grep "Created staging repository with ID" $WORKSPACE/deploy-staged-repository.log | cut -d '"' -f2`
echo BUNDLEURL=${NEXUSURL}/${REPOID}/org/opendaylight/integration/distribution-karaf/${VERSION}/distribution-karaf-${VERSION}.zip > $WORKSPACE/variables.prop
echo "BUNDLEURL: ${BUNDLEURL}"

# Copy variables.prop to variables.jenkins-trigger so that the end of build
# trigger can pick up the file as input for triggering downstream jobs.
# This allows variables.prop to get archive to logs.opendaylight.org while not
# breaking the downstream trigger due to missing file from archiving.
cp variables.prop variables.jenkins-trigger
