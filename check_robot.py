# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
"""Ensures that we are only ever using one robot system.

Due to the way the Jenkins OpenStack Cloud plugin works we can only limit
max parallel robot systems by the VM. So having multiple VM types makes it
very difficult for us to properly limit the amount of parallel robot runs.
"""

__author__ = "Thanh Ha"


import fnmatch
import os
import re
import sys


def get_robot_systems(filename):
    """Scan for robot vms.

    Returns a list of Robot systems found in file.
    """
    robots = set()

    with open(filename, "r") as _file:
        for num, line in enumerate(_file, 1):
            if re.search("centos[78]-robot", line):
                robots.add(line.rsplit(maxsplit=1)[1])

    return robots


if __name__ == "__main__":
    robots = []
    for root, dirnames, filenames in os.walk("jjb"):
        for filename in fnmatch.filter(filenames, "*.yaml"):
            robots += get_robot_systems(os.path.join(root, filename))

    if len(robots) > 1:
        print("ERROR: More than one robot system type definition detected.")
        print("Please ensure that ALL templates use the same robot nodes.")
        print("Infra does not support more than 1 robot node type in use.")
        sys.exit(1)
