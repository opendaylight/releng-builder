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

mkdir -p hide/from/pom/files
cd hide/from/pom/files
mkdir -p m2repo/org/opendaylight/

(IFS='
'
for m in `xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' ../../../../pom.xml`; do
    cp -r "/tmp/r/org/opendaylight/$m" m2repo/org/opendaylight/
done)

# Add exception for integration project since they release under the
# integration top-level project.
cp -r "/tmp/r/org/opendaylight/integration" m2repo/org/opendaylight/

mvn org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository -DrepositoryDirectory="`pwd`/m2repo" -DnexusUrl=http://nexus.opendaylight.org/ -DstagingProfileId="21a27b7f3bbb8d" -DserverId="opendaylight.weekly" -s $AUTORELEASE_SETTINGS -gs $ODL_GLOBAL_SETTINGS | tee $WORKSPACE/deploy-staged-repository.log
