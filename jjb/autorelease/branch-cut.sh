#!/bin/bash -l
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script requires the user running the script to have "Create References"
# permission in Gerrit for the "stable/RELEASE" branch. Where RELEASE is an
# official OpenDaylight release. Eg. Oxygen, Nitrogen, Carbon, etc...
#
# Performs 2 actions:
#
#     1) Creates a new branch stable/RELEASE (where release is a ODL release,
#        eg Oxygen, Nitrogen, Carbon, etc...)
#     2) Updates .gitreview in the new stable/RELEASE branch to set the
#        defaultbranch to the new branch.
#
# Required Parameters:
#     RELEASE: The name of the release to create a branch for.

mkdir -p "$WORKSPACE/archives"
LOG_FILE="$WORKSPACE/archives/branch-cut.log"

set -eu -o pipefail

# Validate inputs
if [ -z "$RELEASE" ]; then
    echo "ERROR: RELEASE variable must be set to a release name. Eg Carbon"
    exit 1
fi

# Setup Gerrit remove to ensure Change-Id gets set on commit.
git config --global --add gitreview.username "jenkins-$SILO"
git remote -v
git submodule foreach git review -s
git review -s

# --- Start create new maintenance branch
echo "---> Creating new mainenance branch"
git submodule foreach git fetch origin
git fetch origin
git submodule foreach git checkout -b "stable/${RELEASE,,}" origin/master
git checkout -b "stable/${RELEASE,,}" origin/master

##########
# Verify #
##########

{
    echo "---> Verify maintenance branch"
    git submodule foreach git branch
    git branch
} | tee -a "$LOG_FILE"

########
# Push #
########

if [ "$DRY_RUN" = false ]
then
    echo "Pushing stable/${RELEASE,,} branches to Gerrit"
    git submodule foreach git push gerrit "stable/${RELEASE,,}"
    git push gerrit "stable/$RELEASE"
fi
# --- End create new maintenance branch

# --- Start update .gitreview
echo "---> Update .gitreview"
git submodule foreach sed -i -e "s#defaultbranch=master#defaultbranch=stable/${RELEASE,,}#" .gitreview
git submodule foreach git add .gitreview
git submodule foreach "git commit -sm 'Update .gitreview to stable/${RELEASE,,}'"
sed -i -e "s#defaultbranch=master#defaultbranch=stable/${RELEASE,,}#" .gitreview
git add .gitreview
git commit -sm "Update .gitreview to stable/${RELEASE,,}"

# Generate git patches
patch_dir="$WORKSPACE/archives/patches/git-review"
mkdir -p "$patch_dir"
for module in $(git submodule | awk '{ print $2 }')
do
    pushd "$module"
    git format-patch --stdout "origin/master" > "$patch_dir/${module//\//-}.patch"
    git bundle create "$patch_dir/${module//\//-}.bundle" "origin/master..HEAD"
    popd
done

##########
# Verify #
##########

{
    echo "---> Verify .gitreview"
    git submodule foreach git show HEAD
    git show HEAD
    git submodule foreach git log --oneline -2 --graph --decorate
    git log --oneline -2 --graph --decorate
} | tee -a "$LOG_FILE"

########
# Push #
########

if [ "$DRY_RUN" = false ]
then
    echo "Pushing .gitreview patches to Gerrit"
    git submodule foreach git review -t "branch-cut-${RELEASE,,}"
    git review -t "branch-cut-${RELEASE,,}"
fi
# --- Stop update .gitreview
