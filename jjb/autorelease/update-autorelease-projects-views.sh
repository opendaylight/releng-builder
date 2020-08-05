#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> update-autorelease-projects-views.sh"

VIEWS_AR_YAML_FILE="${WORKSPACE}/jjb/autorelease/view-autorelease-${STREAM}.yaml"
BRANCH="stable/${STREAM}"

# The current development release will not have a stable branch defined so if
# branch does not exist assume master
url="https://git.opendaylight.org/gerrit/projects/releng%2Fautorelease/branches/"
resp=$(curl -s -w "\\n\\n%{http_code}" --globoff -H "Content-Type:application/json" "$url")
if [[ ! "$resp" =~ $BRANCH ]]; then
    BRANCH="master"
fi

wget -nv -O /tmp/pom.xml "https://git.opendaylight.org/gerrit/gitweb?p=releng/autorelease.git;a=blob_plain;f=pom.xml;hb=$GERRIT_BRANCH"

# handle list of projects read from the pom.xml output as multiple lines.
mapfile -t modules < <(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' /tmp/pom.xml)

cat > "$VIEWS_AR_YAML_FILE" << EOF
---
# Autogenerated view by autorelease autorelease-update-validate-jobs-{stream} Jenkins job
- releng_view: &releng_autorelease_view_common_${STREAM}
    name: releng-view-autorelease-${STREAM}
    view-type: list
    filter-executors: false
    filter-queue: false
    columns:
      - status
      - weather
      - job
      - last-success
      - last-failure
      - last-duration
      - build-button
      - jacoco
      - find-bugs
      - robot-list
    recurse: false

- view:
    name: Merge-${STREAM^}
    description: 'List of ${STREAM^} Merge jobs for Autorelease'
    job-name:
EOF

for module in "${modules[@]}"; do
    echo "Include project:$module to autorelease view"
    echo "      - '$module-maven-merge-${STREAM}'" >> "$VIEWS_AR_YAML_FILE"
done
echo "    <<: *releng_autorelease_view_common_${STREAM}" >> "$VIEWS_AR_YAML_FILE"

git add "${VIEWS_AR_YAML_FILE}"

mkdir -p "${WORKSPACE}/archives"
cp "${VIEWS_AR_YAML_FILE}" "${WORKSPACE}/archives"
