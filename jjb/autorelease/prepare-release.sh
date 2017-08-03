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
# RELEASE_BRANCH=stable/beryllium  # Example

# Set release tag as $STREAM, when no release tag is passed
RELEASE_TAG="${RELEASE_TAG:-${STREAM^}}"
# Ensure that the first letter of RELEASE_TAG is uppercase.
RELEASE_TAG="${RELEASE_TAG^}"

# Directory to put git format-patches
PATCH_DIR="$WORKSPACE/patches"

echo "$RELEASE_TAG"
# Remove this case statement when Carbon is no longer supported.
# Nitrogen onwards we do not want to use the release tag so simply need to
# strip xml files of -SNAPSHOT tags.
case "$RELEASE_TAG" in
    Boron*|Carbon*)
        lftools version release "$RELEASE_TAG"
        ;;
    *)
        find . -name "*.xml" -print0 | xargs -0 sed -i 's/-SNAPSHOT//'
        ;;
esac
git submodule foreach "git commit -am \"Release $RELEASE_TAG\" || true"
git commit -am "Release $RELEASE_TAG"

mkdir patches
# TODO: Fix this workaround so that scripts will ensure that taglist.log exists and archived.
mv taglist.log "$PATCH_DIR" || true
modules=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' pom.xml)
for module in $modules; do
    pushd "$module"
    git format-patch --stdout "origin/$RELEASE_BRANCH" > "$PATCH_DIR/${module//\//-}.patch"
    git bundle create "$PATCH_DIR/${module//\//-}.bundle" "origin/master..HEAD"
    popd
done

tar cvzf patches.tar.gz -C "$WORKSPACE" patches
rm "$PATCH_DIR"/*.bundle
