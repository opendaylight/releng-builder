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
# Ensures that the prefix MUST be set to blank
#
# The production prefix MUST always be a blank string.

if grep 'prefix:' jjb/releng-defaults.yaml | grep -v "''"; then
    echo "ERROR: A non-blank prefix is defined in jjb/releng-defaults.yaml"
    echo "The prefix MUST be set to blank '' in production!"
    exit 1
fi
