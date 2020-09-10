# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
"""Ensures that the prefix MUST be set to blank.

The production prefix MUST always be a blank string.
"""

__author__ = "Thanh Ha"


import os
import re
import sys


def check_prefix(filename):
    """Check if a prefix was checked into this repo."""
    with open(filename, "r") as _file:
        for num, line in enumerate(_file, 1):
            if re.search(" +" "prefix:", line):
                if '""' not in line:
                    print(
                        "ERROR: A non-blank prefix is defined in "
                        "jjb/defaults.yaml. The prefix MUST be set to blank "
                        '"" in production!'
                    )
                    sys.exit(1)


if __name__ == "__main__":
    check_prefix(os.path.join("jjb", "defaults.yaml"))
