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

# Create new maintenance branch
git submodule foreach git fetch origin
git submodule foreach git checkout -b stable/$RELEASE origin/master
git fetch origin
git checkout -b stable/$RELEASE origin/master

git submodule foreach git push gerrit stable/$RELEASE
git push gerrit stable/$RELEASE

# Update .gitreview
git submodule foreach sed -i -e "s#defaultbranch=master#defaultbranch=stable/${RELEASE,,}#" .gitreview
git submodule foreach git add .gitreview
git submodule foreach git commit -asm "Update .gitreview to stable/${RELEASE,,}"
sed -i -e "s#defaultbranch=master#defaultbranch=stable/${RELEASE,,}#" .gitreview
git add .gitreview
git commit -sm "Update .gitreview to stable/${RELEASE,,}"

git submodule foreach git review -t "${RELEASE,,}-branch-cut"
git review -t "${RELEASE,,}-branch-cut"

# Bump and submit patches
lftools version bump
git submodule foreach git commit -asm "Next version bump"
git submodule foreach git review -t "${RELEASE,,}"
