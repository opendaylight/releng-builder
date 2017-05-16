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

# install lftools from the script in global-jjb
global-jjb/shell/lftools-install.sh
# shellcheck disable=SC1090
source "$LFTOOLS_DIR/bin/activate"

# Directory to put git format-patches
PATCH_DIR="$WORKSPACE/patches"

echo "$RELEASE_TAG"
lftools version release "$RELEASE_TAG"
git submodule foreach "git commit -am \"Release $RELEASE_TAG\" || true"
git commit -am "Release $RELEASE_TAG"

mkdir patches
mv taglist.log "$PATCH_DIR"
modules=$(xmlstarlet sel -N x=http://maven.apache.org/POM/4.0.0 -t -m '//x:modules' -v '//x:module' pom.xml)
for module in $modules; do
    pushd "$module"
    git format-patch --stdout "origin/$RELEASE_BRANCH" > "$PATCH_DIR/${module//\//-}.patch"
    git bundle create "$PATCH_DIR/${module//\//-}.bundle" "origin/master..HEAD"
    popd
done

tar cvzf patches.tar.gz -C "$WORKSPACE" patches
rm "$PATCH_DIR"/*.bundle
