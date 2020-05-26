#!/bin/bash -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# This script generates Service Release notes and appends them to the release
# notes in the docs project and submits a patch.

set -x

pip install --user --quiet --upgrade git-review

RELEASE=${RELEASE:-$(echo "$GERRIT_EVENT_COMMENT_TEXT" | grep generate-release-notes | awk '{print $2}')}
if [ -z "$RELEASE" ]; then
    echo "ERROR: The RELEASE variable is not set."
    exit 1
fi

./scripts/release-notes-generator.sh "$RELEASE"

# Archive the notes
if [ -f  "$WORKSPACE/release-notes.rst" ]; then
    mkdir -p "$WORKSPACE/archives"
    cp -f "$WORKSPACE/release-notes.rst" "$WORKSPACE/archives/${RELEASE,,}"
fi

# Generate a docs patch for the notes
DOCS_DIR=$(mktemp -d)
git clone -b "$GERRIT_BRANCH" https://git.opendaylight.org/gerrit/docs.git "$DOCS_DIR"
cd "$DOCS_DIR" || exit 1
cp "$WORKSPACE/release-notes.rst" "docs/release-notes/release-notes-${RELEASE,,}.rst"
git add docs/release-notes/

GERRIT_COMMIT_MESSAGE="Update release notes for $RELEASE"
GERRIT_TOPIC="autogenerate-release-notes"
CHANGE_ID=$(ssh -p 29418 "jenkins-$SILO@git.opendaylight.org" gerrit query \
               limit:1 owner:self is:open project:docs \
               message:"$GERRIT_COMMIT_MESSAGE" \
               topic:"$GERRIT_TOPIC" | \
               grep 'Change-Id:' | \
               awk '{{ print $2 }}')

if [ -z "$CHANGE_ID" ]; then
    git commit -sm "$GERRIT_COMMIT_MESSAGE"
else
    git commit -sm "$GERRIT_COMMIT_MESSAGE" -m "Change-Id: $CHANGE_ID"
fi

git status
git remote add gerrit "ssh://jenkins-$SILO@git.opendaylight.org:29418/docs.git"

# Don't fail the build if this command fails because it's possible that there
# is no changes since last update.
git review --yes -t "$GERRIT_TOPIC" || true
