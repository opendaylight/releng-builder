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

if git log --show-signature -1 | egrep -q 'gpg: Signature made.*key ID'; then
   echo "git commit is gpg signed"
else
   echo "WARNING: gpg signature missing for the commit"
fi

# Don't fail the job for unsigned commits
exit 0
