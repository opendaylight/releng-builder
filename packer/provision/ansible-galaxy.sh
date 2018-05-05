#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

ANSIBLE_ROLES_PATH="${1:-.galaxy}"
ANSIBLE_REQUIREMENTS_FILE="${2:-requirements.yaml}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ansible-galaxy install -p "$ANSIBLE_ROLES_PATH" -r "$SCRIPT_DIR/requirements.yaml"

if [ -f "$ANSIBLE_REQUIREMENTS_FILE" ]; then
    ansible-galaxy install -p "$ANSIBLE_ROLES_PATH" -r "requirements.yaml"
fi
