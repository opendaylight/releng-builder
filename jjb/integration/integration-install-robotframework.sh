#!/bin/sh -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# vim: sw=4 ts=4 sts=4 et ft=sh :

ROBOT_VENV="/tmp/v/robot"
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
python3 -m venv "${ROBOT_VENV}"
# shellcheck disable=SC1090
. "${ROBOT_VENV}/bin/activate"

set -exu

# Make sure pip itself us up-to-date.
python -m pip install --upgrade pip

echo "Installing Python Requirements"
cat << 'EOF' > "requirements.txt"
docker-py
ipaddr
netaddr
netifaces
pyhocon
requests
robotframework-httplibrary
robotframework-requests==0.7.2
robotframework-selenium2library
robotframework-sshlibrary==3.1.1
scapy

# Module jsonpath is needed by current AAA idmlite suite.
jsonpath-rw

# Modules for longevity framework robot library
elasticsearch
elasticsearch-dsl

# Module for pyangbind used by lispflowmapping project
pyangbind

# Module for iso8601 datetime format
isodate

# Module for TemplatedRequests.robot library
jmespath

# Module for backup-restore support library
jsonpatch

# odltools for extra debugging
odltools
EOF
python -m pip install -r requirements.txt
# Todo: Workaround needs pinned version of odltool to the latest because of the
# update in the dependency resolver in pip 21.3.
# Ref: https://github.com/pypa/pip/issues/9215
pip install odltools==0.1.34
odltools -V
pip freeze
