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

(IFS='
'
for m in `xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' ../../../../pom.xml`; do
    rsync -avz --exclude 'maven-metadata*' \
               --exclude '_remote.repositories' \
               --exclude 'resolver-status.properties' \
               "stage/org/opendaylight/$m" m2repo/org/opendaylight/
done)

# Add exception for integration project since they release under the
# integration top-level project.
rsync -avz --exclude 'maven-metadata*' \
           --exclude '_remote.repositories' \
           --exclude 'resolver-status.properties' \
           "stage/org/opendaylight/integration" m2repo/org/opendaylight/

"$MVN" -V -B org.sonatype.plugins:nexus-staging-maven-plugin:1.6.2:deploy-staged-repository \
    -DrepositoryDirectory="`pwd`/m2repo" \
    -DnexusUrl=https://nexus.opendaylight.org/ \
    -DstagingProfileId="425e43800fea70" \
    -DserverId="opendaylight.staging" \
    -s $SETTINGS_FILE \
    -gs $GLOBAL_SETTINGS_FILE | tee $WORKSPACE/deploy-staged-repository.log
