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

# Note: To re-use the venv use the below example in the start of
# the script where every required.
# lf-activate-venv --venv-file ${WORKSPACE}/.robot_venv

# shellcheck disable=SC1090
. ~/lf-env.sh

lf-activate-venv --python python3 --venv-file ${WORKSPACE}/.robot_venv \
    docker-py \
    ipaddr    \
    netaddr   \
    netifaces \
    pyhocon   \
    requests  \
    robotframework-httplibrary        \
    robotframework-requests==0.7.2    \
    robotframework-selenium2library   \
    robotframework-sshlibrary==3.1.1  \
    scapy             \
    jsonpath-rw       \
    elasticsearch     \
    elasticsearch-dsl \
    pyangbind         \
    isodate           \
    jmespath          \
    jsonpatch         \
    odltools==0.1.34

ROBOT_VENV=$(cat "${WORKSPACE}/.robot_venv")
echo ROBOT_VENV="${ROBOT_VENV}" >> "${WORKSPACE}/env.properties"

odltools -V
pip freeze
