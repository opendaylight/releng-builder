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
parser.add_argument("-d", "--dependencies",
                    help=("Project dependencies\n\n"
                          "A comma-seperated (no spaces) list of projects "
                          "your project depends on. "
                          "This is used to create an integration job that "
                          "will trigger when a dependent project-merge job "
                          "is built successfully.\n\n"
                          "Example: aaa,controller,yangtools"))
parser.add_argument("-b", "--branches", help="Git Branches to build")
parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
parser.add_argument("-o", "--mvn-opts", help="Maven Options")
parser.add_argument("-z", "--no-cfg", action="store_true",
                    help=("Disable initializing the project.cfg file."))
args = parser.parse_args()

project = args.project
project_dir = os.path.join("jjb", project)
project_file = os.path.join(project_dir, "%s.yaml" % project)
branches = args.branches    # Defaults to "master,stable/helium" if not passed
mvn_goals = args.mvn_goals  # Defaults to "clean install" if not passsed
mvn_opts = args.mvn_opts    # Defaults to blank if not passed
dependencies = args.dependencies
dependent_jobs = ""
disabled = "true"   # Always disabled unless project has dependencies
email_prefix = "[%s]" % project

template_file = os.path.join("jjb", "job.yaml.template")

# The below 2 variables are used to determine if we should generate a CFG file
# for a project automatically.
#
# no_cfg - is a commandline parameter that can be used by scripts such as the
#          jjb-autoupdate-project script to explicitly disable generating CFG
#          files.
# make_cfg - is a internal variable used to decide if we should try to
#            auto generate the CFG file for a project based on optional
#            variables passed by the user on the commandline.
no_cfg = args.no_cfg
make_cfg = False  # Set to true if we need to generate initial CFG file
cfg_string = []

if not branches:
    branches = "master,stable/helium"
    sonar_branch = "master"
else:
    make_cfg = True
    cfg_string.append("BRANCHES: %s" % branches)
    # For projects who use a different development branch than master
    sonar_branch = branches.split(",")[0]
# Create YAML to list branches to create jobs for
streams = "stream:\n"
for branch in branches.split(","):
    streams = streams + ("        - %s:\n"
                         "            branch: '%s'\n" %
                         (branch.replace('/', '-'),
                          branch))

if not mvn_goals:
    mvn_goals = ("clean install "
                 "-V "  # Show Maven / Java version before building
                 "-Dmaven.repo.local=$WORKSPACE/.m2repo "
                 "-Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo ")
else:  # User explicitly set MAVEN_OPTS so create CFG
    make_cfg = True
    cfg_string.append("MAVEN_GOALS: %s" % mvn_goals)

if not mvn_opts:
    mvn_opts = "-Xmx1024m -XX:MaxPermSize=256m"
else:  # User explicitly set MAVEN_OPTS so create CFG
    make_cfg = True
    cfg_string.append("MAVEN_OPTS: %s" % mvn_opts)

if dependencies:
    make_cfg = True
    disabled = "false"
    email_prefix = (email_prefix + " " +
                    " ".join(['[%s]' % d for d in dependencies.split(",")]))
    dependent_jobs = ",".join(
        ['%s-merge-{stream}' % d for d in dependencies.split(",")])
    cfg_string.append("DEPENDENCIES: %s" % dependencies)

# Create project directory if it doesn't exist
if not os.path.exists(project_dir):
    os.makedirs(project_dir)

print("project: %s\n"
      "branches: %s\n"
      "goals: %s\n"
      "options: %s\n"
      "dependencies: %s" %
      (project,
       branches,
       mvn_goals,
       mvn_opts,
       dependencies))

# Create initial project CFG file
if not no_cfg and make_cfg:
    print("Creating %s.cfg file" % project)
    cfg_file = os.path.join(project_dir, "%s.cfg" % project)
    with open(cfg_file, "w") as outstream:
        cfg = "\n".join(cfg_string)
        outstream.write(cfg)

# Create initial project YAML file
with open(template_file, "r") as infile:
    with open(project_file, "w") as outfile:
        for line in infile:
            if not re.match("\s*#", line):
                line = re.sub("PROJECT", project, line)
                line = re.sub("DISABLED", disabled, line)
                line = re.sub("STREAMS", streams, line)
                line = re.sub("MAVEN_GOALS", mvn_goals, line)
                line = re.sub("MAVEN_OPTS", mvn_opts, line)
                line = re.sub("DEPENDENCIES", dependent_jobs, line)
                line = re.sub("EMAIL_PREFIX", email_prefix, line)
                line = re.sub("SONAR_BRANCH", sonar_branch, line)
            outfile.write(line)

print sonar_branch