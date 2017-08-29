#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
#
# Todo: remove this script once change no 5753 is merged in global-jjb
# This script publishes OpFlex artifacts to Nexus repository.
#
# $MAVEN_REPO_URL          :  Jenkins global variable should be defined.
# $REPO_ID                 :  Provided by a job parameter.
# $GROUP_ID                :  Provided by a job parameter.
# $UPLOAD_FILES_PATH        :  Provided by a job parameter.
echo "---> scripts/deploy-opflex.sh"

# DO NOT enable -u because $MAVEN_PARAMS and $MAVEN_OPTIONS could be unbound.
# Ensure we fail the job if any steps fail.
set -e -o pipefail
set +u

export MAVEN_OPTIONS
export MAVEN_PARAMS

DEPLOY_LOG="$WORKSPACE/archives/deploy-maven-file.log"
mkdir -p "$WORKSPACE/archives"

while IFS="" read -r file
do
    lftools deploy maven-file "$MAVEN_REPO_URL" \
                              "$REPO_ID" \
                              "$file" \
                              -b "$MVN" \
                              -g "$GROUP_ID" \
                              -p "$MAVEN_PARAMS $MAVEN_OPTIONS" \
                              |& tee "$DEPLOY_LOG"
done < <(find "$UPLOAD_FILES_PATH" -type f -name "*")
