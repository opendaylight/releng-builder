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
    echo "Usage: $0 <release_name> <PUBLISH>"
    echo ""
    echo "    release_name:  The release_name e.g Titanium, Vanadium."
    echo "    PUBLISH:  Set to true to PUBLISH"
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

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 "git-review==2.3.1"

# Workaround for git-review failing to copy the commit-msg hook to submodules
git config core.hooksPath "$(git rev-parse --show-toplevel)/.git/hooks"

git config --global --add gitreview.username "jenkins-$SILO"
cd "$WORKSPACE"/autorelease || exit
GERRIT_PROJECT="releng/autorelease"
if [ "$GERRIT_PROJECT" == "releng/autorelease" ]; then
    # User input
    RELEASE_NAME=${RELEASE_NAME:-}
    # Captilize Version Name
    release_name="$(tr '[:lower:]' '[:upper:]' <<< "${RELEASE_NAME:0:1}")${RELEASE_NAME:1}"
    echo "Start Version Updating in odl-projects"
    echo "RELEASE_NAME : $release_name"
    ################
    # Start script #
    ###############
    git submodule update
    #'|| true' for repo like serviceutils where docs/conf.yaml doesn't exist
    command='sed -i ''"s/.*version.*/version: '"$release_name"'/"'' docs/conf.yaml || true'
    git submodule foreach "git checkout $GERRIT_BRANCH"
    echo "git checkout $GERRIT_BRANCH"
    git submodule foreach "git branch"
    git submodule foreach "$command"
    # Workaround for git-review failing to copy the commit-msg hook to submodules
    # git submodule foreach 'git config core.hooksPath "$(git rev-parse --show-toplevel)/.git/hooks"'
    if [ "$PUBLISH" == "true" ]
      then
        echo "Update docs header to $release_name in $STREAM"
        git submodule foreach "git add . || true"
        git submodule foreach "git commit -s -m 'Update docs header to $release_name in $STREAM

    Should be $release_name on $STREAM.' || true"
        git submodule foreach "git review || true"
    fi
fi
