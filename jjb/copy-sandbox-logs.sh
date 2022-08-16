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
# Allows folks to copy sandbox logs over to releng for longer storage
#
# In some cases folks would like to save sandbox logs for a longer period of
# time in order to troubleshoot difficult tasks. This script can be used to
# trigger Jenkins production to copy specific logs over for longer storage.
#
# This is triggered via Gerrit comment.
# Usage: copy-logs: JOB_NAME/BUILD_NUMBER
echo "---> copy-sandbox-logs.sh"

build_path="$(echo "$GERRIT_EVENT_COMMENT_TEXT" | base64 -d | grep 'copy-logs:' | awk -F: '{print $2}' | tr -d '[:space:]')"
fetch_url="https://s3-logs.opendaylight.org/logs/sandbox/vex-yul-odl-jenkins-2/$build_path"

COPY_DIR="$WORKSPACE/archives"
mkdir -p "$COPY_DIR"
initdir=$(pwd)
cd "$COPY_DIR" || exit

# Ensure that the repo_url has a trailing slash as wget needs it to work
case "$fetch_url" in
    */)
        ;;
    *)
        fetch_url="$fetch_url/"
        ;;
esac

echo "Fetching artifacts from $fetch_url..."
wget -nv --recursive --execute robots=off --no-parent \
    --no-host-directories --cut-dirs=2 --level=15 \
    "$fetch_url"

echo "Removing files that do not need to be cloned..."
remove_files=$(find . -type f -name "*index.html*")
for f in $remove_files; do
    rm "$f"
done
cd $initdir || exit
