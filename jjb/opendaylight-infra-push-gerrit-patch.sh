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

# Install git-review using virtualenv to the latest version that supports
# --reviewers option, available through pip install. Existing minion image has a
# version that does not have it.
virtualenv "/tmp/v/git-review"
# shellcheck source=/tmp/v/git-review/bin/activate disable=SC1091
source "/tmp/v/git-review/bin/activate"
pip install --upgrade "pip<10.0.0" setuptools
pip install --upgrade git-review
pip freeze

# shellcheck disable=SC1083
CHANGE_ID=$(ssh -p 29418 "jenkins-$SILO@git.opendaylight.org" gerrit query \
               limit:1 owner:self is:open project:{project} \
               message:'{gerrit-commit-message}' \
               topic:{gerrit-topic} | \
               grep 'Change-Id:' | \
               awk '{{ print $2 }}')

if [ -z "$CHANGE_ID" ]; then
    git commit -sm "{gerrit-commit-message}"
else
    git commit -sm "{gerrit-commit-message}" -m "Change-Id: $CHANGE_ID"
fi

git status
git remote add gerrit "ssh://jenkins-$SILO@git.opendaylight.org:29418/releng/builder.git"

# Don't fail the build if this command fails because it's possible that there
# is no changes since last update.
# shellcheck disable=SC1083
git review --yes -t {gerrit-topic} --reviewers jluhrsen@redhat.com || true
