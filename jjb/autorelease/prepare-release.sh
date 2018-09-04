#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015, 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Script to prepare project for release.
#
# 1) Drop -SNAPSHOT from all versions
# 2) Create git patches (diffs of changes)
# 3) Create git bundles (byte exact commit objects)
# 4) Create tarball for distribution.

# RELEASE_TAG=Beryllium-SR1  # Example

echo "---> prepare-release.sh"

# Set release tag as $STREAM, when no release tag is passed
RELEASE_TAG="${RELEASE_TAG:-${STREAM^}}"
# Ensure that the first letter of RELEASE_TAG is uppercase.
RELEASE_TAG="${RELEASE_TAG^}"

# Directory to put git format-patches
PATCH_DIR="$WORKSPACE/archives/patches"
mkdir -p "$PATCH_DIR"

# Get the current submodule commit hashes.
echo autorelease "$(git rev-parse --verify HEAD)" "${RELEASE_TAG}" \
    | tee -a "$PATCH_DIR/taglist.log"
# Disable SC2154 because we want $path to be the submodule parameter not the shell.
# shellcheck disable=SC2154
git submodule foreach "echo \$path \$(git rev-parse --verify HEAD) ${RELEASE_TAG} \
    | tee -a $PATCH_DIR/taglist.log"

echo "$RELEASE_TAG"
find . -name "*.xml" -print0 | xargs -0 sed -i 's/-SNAPSHOT//'

# Ignore changes to Final distribution since that will be released separately
pushd integration/distribution
    git checkout -f opendaylight/pom.xml
popd
git submodule foreach "git commit -am \"Release $RELEASE_TAG\" || true"
git commit -am "Release $RELEASE_TAG"

modules=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' pom.xml)
for module in $modules; do
    pushd "$module" || exit
    git format-patch --stdout "origin/$GERRIT_BRANCH" > "$PATCH_DIR/${module//\//-}.patch"
    git bundle create "$PATCH_DIR/${module//\//-}.bundle" "origin/master..HEAD"
    popd || exit
done

tar cvzf "$WORKSPACE/archives/patches.tar.gz" -C "$WORKSPACE/archives" patches
rm "$PATCH_DIR"/*.bundle
