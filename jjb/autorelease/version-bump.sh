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

# This script performs version bumping activities for an ODL release.
echo "---> version-bump.sh"

mkdir -p "$WORKSPACE/archives"
LOG_FILE="$WORKSPACE/archives/version-bump.log"
BRANCH="$GERRIT_BRANCH"

# Ensure we fail the job if any steps fail.
set -eu -o pipefail

git checkout -b "${BRANCH,,}" "origin/${BRANCH,,}"
git submodule foreach git checkout -b "${BRANCH,,}" "origin/${BRANCH,,}"

# Check if git state is clean
git status

lftools version release "$RELEASE_TAG"
lftools version bump "$RELEASE_TAG"

git submodule foreach "git commit -asm 'Bump versions by x.y.(z+1)'"
# Only submodules need to be bumped, we can ignore autorelease's bump information
git checkout -f

# Generate git patches
patch_dir="$WORKSPACE/archives/patches/version-bump"
mkdir -p "$patch_dir"
for module in $(git submodule | awk '{ print $2 }')
do
    pushd "$module"
    git format-patch --stdout "origin/${BRANCH,,}" > "$patch_dir/${module//\//-}.patch"
    git bundle create "$patch_dir/${module//\//-}.bundle" "origin/${BRANCH,,}..HEAD"
    popd
done

# Verify
{
    echo "----> Verify version bump"
    git submodule foreach git show HEAD
    git show HEAD
    find . -name pom.xml -print0 | xargs -0 grep "$RELEASE_TAG" || true
    git status
    ls "$patch_dir"
} | tee -a "$LOG_FILE"

# Push
if [ "$DRY_RUN" = "false" ]
then
    # Run a build here! Should be safe to run mvn clean deploy as nothing should be
    # using the version bumped versions just yet.
    ./scripts/fix-relativepaths.sh
    "$MVN" clean install -Pq \
    -s "$SETTINGS_FILE" \
    -gs "$GLOBAL_SETTINGS_FILE" \
    --show-version \
    --batch-mode \
    -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
    -Djenkins \
    -Dmaven.repo.local=/tmp/r \
    -Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r

    # Push up patches last, as long as nothing failed.
    git submodule foreach "git remote add gerrit '$GIT_URL/$PROJECT'"
    git submodule foreach "git review --yes -t '${RELEASE_TAG}' || true"
fi

echo "Version bumping complete."
