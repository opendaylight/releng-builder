#!/bin/sh
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# Ensure we fail the job if any steps fail.
# shellcheck disable=SC3040
set -eu -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 lftools

MAVEN_GROUP_ID=$(xmlstarlet sel \
      -N "x=http://maven.apache.org/POM/4.0.0" \
      -t \
      --if "/x:project/x:groupId" \
      -v "/x:project/x:groupId" \
      --elif "/x:project/x:parent/x:groupId" \
      -v "/x:project/x:parent/x:groupId" \
      --else -o "" \
      pom.xml 2>/dev/null)

cd "$WORKSPACE/target"
mv staged-site "$STREAM"
zip -r maven-site.zip "$STREAM"
lftools deploy nexus-zip "$NEXUS_URL" site "$MAVEN_GROUP_ID" maven-site.zip
