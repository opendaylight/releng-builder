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
# shellcheck disable=SC2039,SC3040
set -eu -o pipefail

# shellcheck disable=SC1090
. ~/lf-env.sh

# An agent's ~/lf-env.sh is copied when it boots, so may predate lftools-uv.
# shellcheck disable=SC3044  # lf-env.sh is bash; see SC3040 above.
if ! declare -F lftools-uv > /dev/null; then
    lf_env="$(mktemp)"
    lf_env_url="https://raw.githubusercontent.com/lfit/releng-global-jjb"
    wget -nv -O "$lf_env" "$lf_env_url/${GLOBAL_JJB_VERSION:-master}/jenkins-init-scripts/lf-env.sh" || true
    # shellcheck disable=SC1090
    . "$lf_env"
    rm -f "$lf_env"
    # shellcheck disable=SC3044  # lf-env.sh is bash; see SC3040 above.
    if ! declare -F lftools-uv > /dev/null; then
        echo "ERROR: lf-env.sh has no lftools-uv function" >&2
        exit 1
    fi
fi

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
lftools-uv deploy nexus-zip "$NEXUS_URL" site "$MAVEN_GROUP_ID" maven-site.zip
