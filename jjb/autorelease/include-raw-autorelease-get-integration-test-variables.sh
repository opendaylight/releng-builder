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

NEXUSURL=http://nexus.opendaylight.org/content/repositories/
VERSION=`grep -m1 '<version>' ${WORKSPACE}/integration/distribution/distributions/karaf/pom.xml | awk -F'[<|>]' '/version/ { printf $3 }'`
REPOID=`grep "Closing staging repository with ID" $WORKSPACE/deploy-staged-repository.log | cut -d '"' -f2`

echo BUNDLEURL=${NEXUSURL}/${REPOID}/org/opendaylight/integration/distribution-karaf/${VERSION}/distribution-karaf-${VERSION}.zip > $WORKSPACE/variables.prop
