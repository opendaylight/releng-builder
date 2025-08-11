#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2022 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> autorelease-gerrit-branch-lock.sh"
# The script lock's/unlock's a Gerrit branch for code-freeze or release work
# or enable/disable supercommitters rights.

# Ensure we fail the job if any steps fail.
set -eu -o pipefail

mkdir -p "${WORKSPACE}/archives"

git clone "ssh://jenkins-releng@git.opendaylight.org:29418/All-Projects"

cd "${WORKSPACE}/All-Projects"
git config user.name "jenkins-releng"
git config user.email "releng+jenkins-releng@linuxfoundation.org"
git fetch origin refs/meta/config:config
git checkout config

# backup copy of the previous state of project.config
cp project.config "${WORKSPACE}/archives"

install_gerrit_hook() {
    ssh_url=$(git remote show origin | grep Fetch | grep 'ssh://' \
        | awk -F'/' '{print $3}' | awk -F':' '{print $1}')
    ssh_port=$(git remote show origin | grep Fetch | grep 'ssh://' \
        | awk -F'/' '{print $3}' | awk -F':' '{print $2}')

    if [ -z "$ssh_url" ]; then
        echo "ERROR: Gerrit SSH URL not found."
        exit 1
    fi

    scp -p -P "$ssh_port" "$ssh_url":hooks/commit-msg .git/hooks/
    chmod u+x .git/hooks/commit-msg
}
install_gerrit_hook

mode="${GERRIT_ACCESS_MODE}"
set -x
case $mode in
    branch-cut)
        if [ "${GERRIT_BRANCH}" == "master" ] && [[ "${GERRIT_BRANCH_NEXT}" =~ stable ]]; then
            echo "INFO: Locking branch for new branch cutting: ${GERRIT_BRANCH_NEXT}"
            git config -f project.config "access.refs/for/refs/heads/${GERRIT_BRANCH_NEXT}.exclusiveGroupPermissions" "create"
            git config -f project.config "access.refs/for/refs/heads/${GERRIT_BRANCH_NEXT}.create" "block group Registered Users"
            git config -f project.config --add "access.refs/for/refs/heads/${GERRIT_BRANCH_NEXT}.create" "group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH_NEXT}.label-Code-Review" "-2..+2 group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH_NEXT}.label-Verified" "-1..+1 group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH_NEXT}.submit" "block group Registered Users"
            git config -f project.config --add "access.refs/heads/${GERRIT_BRANCH_NEXT}.submit" "group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH_NEXT}.exclusiveGroupPermissions" "submit"
            git config -f project.config --add "access.refs/heads/*.create" "group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Code-Review" "-2..+2 group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Verified" "-1..+1 group Release Engineering Team"
            git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.submit" "block group Registered Users"
            git config -f project.config --add "access.refs/heads/${GERRIT_BRANCH}.submit" "group Release Engineering Team"
            git commit -asm "Chore: Lock for new branch cutting: ${GERRIT_BRANCH_NEXT}"
        else
            echo "ERROR: Cannot perform branch cutting on non-master branch."
            echo "ERROR: stable branch should be ex: stable/titanium"
            exit 1
        fi
        ;;
    supercommitters)
        echo "INFO: Locking branch for MRI: ${GERRIT_BRANCH}"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.exclusiveGroupPermissions" "submit"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.submit" "group Release Engineering Team"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.removeReviewer" "group Release Engineering Team"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Code-Review" "-2..+2 group Release Engineering Team"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Verified" "-1..+1 group Release Engineering Team"
        git commit -asm "Chore: Grant supercommitters rights ${GERRIT_BRANCH}"
        ;;
    code-freeze)
        echo "INFO: Locking branch for code-freeze: ${GERRIT_BRANCH}"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.exclusiveGroupPermissions" "submit"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.submit" "block group Registered Users"
        git commit -asm "Chore: Lock ${GERRIT_BRANCH} for code-freeze"
        ;;
    release-prep)
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.exclusiveGroupPermissions" "submit"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.submit" "block group Registered Users"
        git config -f project.config --add "access.refs/heads/${GERRIT_BRANCH}.submit" "group Release Engineering Team"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Code-Review" "-2..+2 group Release Engineering Team"
        git config -f project.config "access.refs/heads/${GERRIT_BRANCH}.label-Verified" "-1..+1 group Release Engineering Team"
        git commit -asm "Chore: Lock ${GERRIT_BRANCH} for Release Work"
        ;;
    unlock)
        echo "INFO: Unlocking branch: ${GERRIT_BRANCH}"
        git config -f project.config --remove-section "access.refs/heads/${GERRIT_BRANCH}" || true
        git commit -asm "Chore: Unlock branch ${GERRIT_BRANCH}"
        ;;
    *)
        echo "ERROR: Unknown mode:'$mode'."
        exit 1
        ;;
esac

git diff HEAD~1
if [ "$DRY_RUN" = true ]; then
    echo "INFO: DRY RUN enabled, skip pushing changes to the repository."
else
    echo "INFO: Pushing changes to the repository."
    git push origin HEAD:refs/meta/config
fi
