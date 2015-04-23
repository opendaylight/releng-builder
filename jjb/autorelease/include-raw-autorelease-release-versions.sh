#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

# RELEASE_TAG=Helium-SR2  # Example
# RELEASE_BRANCH=stable/helium  # Example

./scripts/version.sh release $RELEASE_TAG
git submodule foreach "git commit -am \"Release $RELEASE_TAG\" || true"
git commit -am "Release $RELEASE_TAG"

mkdir patches
git submodule foreach 'git format-patch --stdout origin/$RELEASE_BRANCH > ../patches/$name.patch'

./scripts/fix-relativepaths.sh
