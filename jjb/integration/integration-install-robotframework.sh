#!/bin/bash -l
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

# shellcheck disable=SC1090
. ~/lf-env.sh

# Create a virtual environment for robot tests and make sure setuptools & wheel
# are up-to-date in addition to pip
lf-activate-venv --python python3 --venv-file "${WORKSPACE}/.robot_venv" \
    setuptools \
    wheel

# Save the virtual environment in ROBOT_VENV
ROBOT_VENV="$(cat "${WORKSPACE}/.robot_venv")"
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

set -exu

echo "Installing Python Requirements"
cat << 'EOF' > "requirements.txt"
docker-py
ipaddr
netaddr
netifaces
pyhocon
requests
robotframework
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
EOF

python -m pip install -r requirements.txt
pip freeze
