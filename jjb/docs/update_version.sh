#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2019 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

update_file_usage () {
    echo "Usage: $0 <release_name> <publish>"
    echo ""
    echo "    release_name:  The release_name e.g Magnesium ."
    echo "    publish:  Set to true to publish"
    echo ""
}
while getopts :h: opts; do
  case "$opts" in
    h)
        update_file_usage
        exit 0
        ;;
    [?])
        update_file_usage
        exit 1
        ;;
  esac
done

# User input
release_name=$RELEASE_NAME
# Captilize Version Name
release_name="$(tr '[:lower:]' '[:upper:]' <<< "${release_name:0:1}")${release_name:1}"
branch_name=$STREAM
publish=$PUBLISH

################
# Start script #
###############
git submodule update

#'|| true' for repo like serviceutils where docs/conf.yaml doesn't exist
command='sed -i ''"s/.*version.*/version: '"$release_name"'/"'' docs/conf.yaml || true'
git submodule foreach "git checkout $branch_name"
git submodule foreach "$command"
if [ "$publish" == "true" ]
  then
    git submodule foreach "git add . || true"
    git submodule foreach "git commit -s -m 'Update docs header to $release_name in $branch_name

Should be $release_name on $branch_name.' || true"
    git submodule foreach "git review || true"
fi
