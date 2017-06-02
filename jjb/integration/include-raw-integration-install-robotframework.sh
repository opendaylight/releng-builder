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

ROBOT_VENV=$(mktemp -d --suffix=robot_venv)
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

# The --system-site-packages parameter allows us to pick up system level
# installed packages. This allows us to bake matplotlib which takes very long
# to install into the image.
virtualenv --system-site-packages "${ROBOT_VENV}"
# shellcheck disable=SC1090
source "${ROBOT_VENV}/bin/activate"
PYTHON="${ROBOT_VENV}/bin/python"

set -exu

# Make sure pip itself us up-to-date.
$PYTHON -m pip install --upgrade pip

$PYTHON -m pip install --upgrade docker-py importlib requests scapy netifaces netaddr ipaddr pyhocon
$PYTHON -m pip install --upgrade robotframework-httplibrary \
    requests==2.15.1 \
    robotframework-requests \
    robotframework-sshlibrary \
    robotframework-selenium2library \
    robotframework-pycurllibrary

# Module jsonpath is needed by current AAA idmlite suite.
$PYTHON -m pip install --upgrade jsonpath-rw

# Modules for longevity framework robot library
$PYTHON -m pip install --upgrade elasticsearch elasticsearch-dsl

# Module for pyangbind used by lispflowmapping project
$PYTHON -m pip install pyangbind

# Module for iso8601 datetime format
$PYTHON -m pip install isodate

# Modules for tornado and jsonpointer used by client libraries of IoTDM project
# Note: Could be removed when client running on tools VM is used instead
#       of client libraries only.
$PYTHON -m pip install --upgrade tornado jsonpointer

# Module for TemplatedRequests.robot library
$PYTHON -m pip install --upgrade jmespath

# Module for backup-restore support library
$PYTHON -m pip install jsonpatch

# Print installed versions.
$PYTHON -m pip freeze

# vim: sw=4 ts=4 sts=4 et ft=sh :
