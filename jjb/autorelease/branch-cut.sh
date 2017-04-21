#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script requires the user running the script to have Create References
# permission in Gerrit.

# Can we test to see if required permissions exist?
# Check permission
# if not exit 1

mkdir -p "$WORKSPACE/archives"
LOG_FILE="$WORKSPACE/archives/branch-cut.log"

set -eu -o pipefail

# Validate inputs
if [ -z "$RELEASE" ]
then
    echo "ERROR: RELEASE variable most be set to a release name. Eg Carbon"
    exit 1
fi

# --- Start create new maintenance branch
echo "---> Creating new mainenance branch"
git submodule foreach git fetch origin
git fetch origin
git submodule foreach git checkout -b "stable/${RELEASE,,}" origin/master
git checkout -b "stable/${RELEASE,,}" origin/master

# Verify
{
    echo "---> Verify maintenance branch"
    git submodule foreach git branch
    git branch
} | tee -a $LOG_FILE

# Push
if [ "$DRY_RUN" = false ]
then
    echo "Pushing stable/${RELEASE,,} branches to Gerrit"
    #git submodule foreach git push gerrit stable/${RELEASE,,}
    #git push gerrit stable/$RELEASE
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
git submodule foreach "git format-patch --stdout 'origin/master' > '$patch_dir/${module//\//-}.patch'"
git submodule foreach "git bundle create '$patch_dir/${module//\//-}.bundle' 'origin/master..HEAD'"
git format-patch --stdout "origin/master" > "$patch_dir/${module//\//-}.patch"
git bundle create "$patch_dir/${module//\//-}.bundle" "origin/master..HEAD"

# Verify
{
    echo "---> Verify .gitreview"
    git submodule foreach git show HEAD
    git show HEAD
    git submodule foreach git log --oneline -2 --graph --decorate
    git log --oneline -2 --graph --decorate
} | tee -a $LOG_FILE

# Push
if [ "$DRY_RUN" = false ]
then
    echo "Pushing .gitreview patches to Gerrit"
    #git submodule foreach git review -t "branch-cut-${RELEASE,,}"
    #git review -t "branch-cut-${RELEASE,,}"
fi
# --- Stop update .gitreview

# --- Start bump and submit patches
echo "---> Create version bump patches"
git submodule foreach git checkout master
git checkout master
# Only submodules need to be bumped, we can ignore autorelease's repo changes.
lftools version bump "$RELEASE"
git submodule foreach "git commit -asm 'Bump versions by x.(y+1).z for $RELEASE dev cycle'"
git checkout -f

# Generate git patches
patch_dir="$WORKSPACE/archives/patches/version-bump"
git submodule foreach "git format-patch --stdout 'origin/master' > '$patch_dir/${module//\//-}.patch'"
git submodule foreach "git bundle create '$patch_dir/${module//\//-}.bundle' 'origin/master..HEAD'"

# Perhaps we can prime Nexus with artifacts for the bumped versions before
# pushing the patches so that they all pass verify and can be merged out of
# order.
#
# Something like mvn clean deploy -Pq might work.

# Verify
{
    echo "Verify version bump"
    git submodule foreach git show HEAD
} | tee -a $LOG_FILE

# Push
if [ "$DRY_RUN" = false ]
then
    echo "Pushing version bump patches to Gerrit"
    #git submodule foreach git review -t "${RELEASE,,}"
fi
# --- End bump and submit patches
