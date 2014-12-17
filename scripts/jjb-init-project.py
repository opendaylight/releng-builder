#!/usr/bin/python

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2014 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Thanh Ha (The Linux Foundation) - Initial implementation
##############################################################################

import argparse
import os
import re

parser = argparse.ArgumentParser()
parser.add_argument("project", help="project")
parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
parser.add_argument("-o", "--mvn-opts", help="Maven Options")
args = parser.parse_args()

project = args.project
project_dir = os.path.join("jjb", project)
project_file = os.path.join(project_dir, "%s.yaml" % project)
mvn_goals = args.mvn_goals  # Defaults to "clean install" if not passsed
mvn_opts = args.mvn_opts    # Defaults to blank if not passed

template_file = os.path.join("jjb", "job.yaml.template")

if not mvn_goals:
    mvn_goals = ("clean install "
                 "-V "  # Show Maven / Java version before building
                 "-Dmaven.repo.local=$WORKSPACE/.m2repo "
                 "-Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo ")

if not mvn_opts:
    mvn_opts = "-Xmx1024m -XX:MaxPermSize=256m"

# Create project directory if it doesn't exist
if not os.path.exists(project_dir):
    os.makedirs(project_dir)

print("project: %s\ngoals: %s\noptions: %s" % (project,
                                               mvn_goals,
                                               mvn_opts))

# Create initial project YAML file
with open(template_file, "r") as infile:
    with open(project_file, "w") as outfile:
        for line in infile:
            if not re.match("\s*#", line):
                line = re.sub("PROJECT", project, line)
            if not re.match("\s*#", line):
                line = re.sub("MAVEN_GOALS", mvn_goals, line)
            if not re.match("\s*#", line):
                line = re.sub("MAVEN_OPTS", mvn_opts, line)
            outfile.write(line)
