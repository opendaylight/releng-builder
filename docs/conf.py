#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
"""Configuration for Sphinx."""

from docs_conf.conf import *  # noqa

linkcheck_ignore = [
    # Gerrit Admin URL
    r"https://git\.opendaylight\.org/gerrit/admin/repos/.*",
    # Gitweb summary and tree views
    r"https://git\.opendaylight\.org/gerrit/gitweb\?.*",
    # (Optional) Catch-all for Gerrit query-params links
    r"https://git\.opendaylight\.org/gerrit/.*[?;].*",
]

# linkcheck configuration
linkcheck_timeout = 60
linkcheck_retries = 3
