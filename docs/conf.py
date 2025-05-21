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

linkcheck_request_headers = {
    r"https://git.opendaylight.org/": {
        "User-Agent": (
            "Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:24.0) Gecko/20100101 Firefox/24.0"
        ),
    },
}

# linkcheck configuration
linkcheck_timeout = 60
linkcheck_retries = 3
