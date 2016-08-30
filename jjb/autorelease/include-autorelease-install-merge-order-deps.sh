#!/bin/bash

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2016 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

AUTOREL_VENV=`mktemp -d --suffix=autorelease_venv`
echo AUTOREL_VENV=${AUTOREL_VENV} >> ${WORKSPACE}/env.properties

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv --system-site-packages ${AUTOREL_VENV}
source ${AUTOREL_VENV}/bin/activate

set -exu

# Make sure pip itself us up-to-date.
pip install --upgrade pip

# Module networkx is to determine-merge-order script.
pip install --upgrade networkx

# Print installed versions.
pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
