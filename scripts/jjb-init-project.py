#!/usr/bin/python

# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2014, 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
# Contributors:
#   Thanh Ha (The Linux Foundation) - Initial implementation
##############################################################################

from collections import OrderedDict
import os
import re
import sys

import yaml

import jjblib


args = jjblib.parse_jjb_args()


project = jjblib.Project(args.project)
if project.meta_project is not None:
    project_dir = os.path.join("jjb", project.meta_project, project.project)
else:
    project_dir = os.path.join("jjb", project.project)

project_file = os.path.join(project_dir, "%s.yaml" % project)
dependent_jobs = ""
disabled = "true"   # Always disabled unless project has dependencies
email_prefix = "[%s]" % project

if not args.conf:
    jjblib.create_template_config(project_dir, args)
    project_conf = os.path.join(project_dir, "%s.cfg" % args.project)
else:
    project_conf = args.conf

cfg = dict()  # Needed to skip missing project.cfg files
if os.path.isfile(project_conf):
    stream = open(project_conf, "r")
    cfg = yaml.load(stream)

####################
# Handle Templates #
####################
if cfg.get('JOB_TEMPLATES'):
    templates = cfg.get('JOB_TEMPLATES')
else:
    templates = "verify,merge,daily,distribution,integration,sonar"
templates += ",clm"  # ensure we always create a clm job for all projects

###################
# Handle Branches #
###################
branches = OrderedDict()
if cfg.get('BRANCHES'):
    for branch in cfg.get('BRANCHES'):
        for b in branch:
            branches.update({b: branch[b]})
else:
    branches.update({"master": {"jdks": "openjdk7"}})

sonar_branch = list(branches.items())[0][0]
# Create YAML to list branches to create jobs for
streams = "stream:\n"
for branch, options in branches.items():
    streams = streams + ("        - %s:\n"
                         "            branch: '%s'\n" %
                         (branch.replace('/', '-'),
                          branch))
    streams = streams + "            jdk: %s\n" % options["jdks"].split(",")[0].strip()  # noqa
    streams = streams + "            jdks:\n"
    for jdk in options["jdks"].split(","):
        streams = streams + "                - %s\n" % jdk.strip()

###############
# Handle JDKS #
###############
if cfg.get('JDKS'):
    jdks = cfg.get('JDKS')
else:
    jdks = "openjdk7"
use_jdks = ""
for jdk in jdks.split(","):
    use_jdks += "                - %s\n" % jdk

##############
# Handle POM #
##############
if cfg.get('POM'):
    pom = cfg.get('POM')
else:
    pom = "pom.xml"

####################
# Handle MVN_GOALS #
####################
if cfg.get('MVN_GOALS'):
    mvn_goals = cfg.get('MVN_GOALS')
else:
    mvn_goals = ("clean install "
                 "-V "  # Show Maven / Java version before building
                 "-Dmaven.repo.local=/tmp/r "
                 "-Dorg.ops4j.pax.url.mvn.localRepository=/tmp/r ")

###################
# Handle MVN_OPTS #
###################
if cfg.get('MVN_OPTS'):
    mvn_opts = cfg.get('MVN_OPTS')
else:
    mvn_opts = "-Xmx1024m -XX:MaxPermSize=256m"

#######################
# Handle DEPENDENCIES #
#######################
if cfg.get('DEPENDENCIES'):
    dependencies = cfg.get('DEPENDENCIES')
    if dependencies.find("odlparent") < 0:  # Add odlparent if not listed
        dependencies = "odlparent," + dependencies
    disabled = "false"
else:
    dependencies = "odlparent"  # All projects depend on odlparent
    disabled = "false"

email_prefix = (email_prefix + " " +
                " ".join(['[%s]' % d for d in dependencies.split(",")]))  # noqa
dependent_jobs = ",".join(
    ['%s-merge-{stream}' % d for d in dependencies.split(",")])

############################
# Handle ARCHIVE_ARTIFACTS #
############################
if cfg.get('ARCHIVE_ARTIFACTS'):
    archive_artifacts = cfg.get('ARCHIVE_ARTIFACTS')
    archive_artifacts = ("- archive-artifacts:\n"
                         "            artifacts: '%s'" % archive_artifacts)
else:
    archive_artifacts = ""


##############################
# Create configuration start #
##############################

# Create project directory if it doesn't exist
if not os.path.exists(project_dir):
    os.makedirs(project_dir)

print("project: %s\n"
      "branches: %s\n"
      "goals: %s\n"
      "options: %s\n"
      "dependencies: %s\n"
      "artifacts: %s" %
      (project,
       branches,
       mvn_goals,
       mvn_opts,
       dependencies,
       archive_artifacts,))

# Create initial project YAML file
use_templates = templates.split(",")
use_templates.insert(0, "project")
job_templates_yaml = ""
for t in use_templates:
    if t == "project":  # This is not a job type but is used for templating
        pass
    elif t == "sonar":
        job_templates_yaml = job_templates_yaml + \
            "        - '%s-%s'\n" % (project, t)
    else:
        job_templates_yaml = job_templates_yaml + \
            "        - '%s-%s-{stream}'\n" % (project, t)

with open(project_file, "w") as outfile:
    for t in use_templates:
        template_file = "jjb-templates/%s.yaml" % t
        with open(template_file, "r") as infile:
            for line in infile:
                if not re.match("\s*#", line):
                    line = re.sub("JOB_TEMPLATES", job_templates_yaml, line)
                    line = re.sub("PROJECT", project.project, line)
                    line = re.sub("DISABLED", disabled, line)
                    line = re.sub("STREAMS", streams, line)
                    line = re.sub("POM", pom, line)
                    line = re.sub("MAVEN_GOALS", mvn_goals, line)
                    line = re.sub("MAVEN_OPTS", mvn_opts, line)
                    line = re.sub("DEPENDENCIES", dependent_jobs, line)
                    line = re.sub("EMAIL_PREFIX", email_prefix, line)
                    line = re.sub("SONAR_BRANCH", sonar_branch, line)
                    line = re.sub("ARCHIVE_ARTIFACTS", archive_artifacts, line)
                    # The previous command may have created superfluous lines.
                    # If a line has no non-whitespace, it has to be '\n' only.
                    line = re.sub(r'^\s+\n', "", line)
                outfile.write(line)
        outfile.write("\n")
