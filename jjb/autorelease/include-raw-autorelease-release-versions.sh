#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015, 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# RELEASE_TAG=Beryllium-SR1  # Example
# RELEASE_BRANCH=stable/beryllium  # Example

# Directory to put git format-patches
PATCH_DIR="$WORKSPACE/archives/patches"
mkdir -p "$PATCH_DIR"

# Get the current submodule commit hashes.
echo autorelease "$(git rev-parse --verify HEAD)" "${RELEASE_TAG}" \
    | tee -a "$PATCH_DIR/taglist.log"
# Disable SC2154 because we want $path to be the submodule parameter not the shell.
# shellcheck disable=SC2154
git submodule foreach "echo \$path $(git rev-parse --verify HEAD) ${RELEASE_TAG} \
    | tee -a $PATCH_DIR/taglist.log"

echo "$RELEASE_TAG"
lftools version release "$RELEASE_TAG"
git submodule foreach "git commit -am \"Release $RELEASE_TAG\" || true"
git commit -am "Release $RELEASE_TAG"

modules=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' pom.xml)
for module in $modules; do
    pushd "$module"
    git format-patch --stdout "origin/$RELEASE_BRANCH" > "$PATCH_DIR/${module//\//-}.patch"
    git bundle create "$PATCH_DIR/${module//\//-}.bundle" "origin/master..HEAD"
    popd
done

tar cvzf "$WORKSPACE/archives/patches.tar.gz" -C "$WORKSPACE/archives/" "$PATCH_DIR"
rm "$PATCH_DIR"/*.bundle
