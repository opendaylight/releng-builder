#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# This script performs version bumping activities for an ODL release and branch
# cutting.
echo "---> version-bump.sh"

# The only purpose of RELEASE_TAG in this script is to set the Gerrit topic.
# It is also used as a placeholder for version bumping but gets wiped out
# immediately to bump versions by x.y.(z+1).
RELEASE_TAG="${STREAM^}"

mkdir -p "$WORKSPACE/archives"
LOG_FILE="$WORKSPACE/archives/version-bump.log"
BRANCH="$GERRIT_BRANCH"

# Ensure we fail the job if any steps fail.
set -eu -o pipefail

# Fail if branch cutting is not on master
if [ "$BRANCH_CUT" = "true" ] && [ "$BRANCH" != "master" ]; then
    echo "ERROR: Cannot branch cut on $BRANCH, its required to be on the master branch."
    exit 1
fi

if [ "$BRANCH_CUT" = "false" ]; then
    git checkout -b "${BRANCH,,}" "origin/${BRANCH,,}"

    # TODO: Simplify once stable/nitrogen is no longer supported.
    for module in $(git submodule | awk '{ print $2 }')
    do
        pushd "$module"
        if [ "$GERRIT_BRANCH" == "stable/nitrogen" ] && [ "$module" == "yangtools" ]; then
            git checkout -b "v1.2.x" "origin/v1.2.x"
        else
            git checkout -b "${BRANCH,,}" "origin/${BRANCH,,}"
        fi
        popd
    done
fi


# Setup Gerrit remove to ensure Change-Id gets set on commit.
git config --global --add gitreview.username "jenkins-$SILO"
git remote add gerrit ssh://jenkins-$SILO@git.opendaylight.org:29418/releng/autorelease.git
git remote -v
git review -s
git submodule foreach "git review -s"

# Check if git state is clean
git status

if [ "$BRANCH_CUT" = "false" ]; then
    lftools version release "$RELEASE_TAG"
fi
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
    # TODO: Remove once stable/nitrogen is no longer supported.
    if [ "$GERRIT_BRANCH" == "stable/nitrogen" ] && [ "$module" == "yangtools" ]; then
        git format-patch --stdout "origin/v1.2.x" > "$patch_dir/${module//\//-}.patch"
        git bundle create "$patch_dir/${module//\//-}.bundle" "origin/v1.2.x..HEAD"
    else
        git format-patch --stdout "origin/${BRANCH,,}" > "$patch_dir/${module//\//-}.patch"
        git bundle create "$patch_dir/${module//\//-}.bundle" "origin/${BRANCH,,}..HEAD"
    fi
    popd
done

##########
# Verify #
##########

{
    echo "----> Verify version bump"
    git submodule foreach git show HEAD
    git show HEAD
    find . -name pom.xml -print0 | xargs -0 grep "$RELEASE_TAG" || true
    git status
    ls "$patch_dir"
} | tee -a "$LOG_FILE"

#########
# Build #
#########

MVN_GOALS=(clean install)
if [ "$DRY_RUN" = "false" ]
then
    # Should be safe to run mvn clean deploy as nothing should be
    # using the version bumped versions just yet.
    MVN_GOALS=(clean deploy)
fi

./scripts/fix-relativepaths.sh
"$MVN" "${MVN_GOALS[@]}" -Pq \
-s "$SETTINGS_FILE" \
-gs "$GLOBAL_SETTINGS_FILE" \
-DaltDeploymentRepository="opendaylight-snapshot::default::https://nexus.opendaylight.org/content/repositories/opendaylight.snapshot" \
--show-version \
--batch-mode \
-Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn \
-Djenkins \
-Dmaven.repo.local=/tmp/r \
-Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r

# Clear any changes caused by Maven build
git checkout -f
git submodule foreach git checkout -f

########
# Push #
########

if [ "$DRY_RUN" = "false" ]
then
    # Push up patches last, as long as nothing failed.
    git submodule foreach git review --yes -t "${RELEASE_TAG}"
fi

echo "Version bumping complete."
