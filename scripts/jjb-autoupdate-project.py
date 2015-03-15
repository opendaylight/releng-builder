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

import os

import yaml


def get_autoupdate_projects(jjb_dir, projects):
    """Get list of projects that should be auto-updated."""
    project_list = []
    for project in projects:
        template = os.path.join(jjb_dir, project, "%s.yaml" % project)
        if os.path.isfile(template):
            with open(template, 'r') as f:
                first_line = f.readline()
            if first_line.startswith("# REMOVE THIS LINE IF"):
                project_list.append(project)

    return project_list


def update_templates(projects):
    for project in projects:

        # If project has customized variables
        cfg_file = "jjb/%s/%s.cfg" % (project, project)
        parameters = ["python scripts/jjb-init-project.py"]
        parameters.append("-z")  # Disable CFG auto-generation
        if os.path.isfile(cfg_file):
            stream = open(cfg_file, "r")
            cfg = yaml.load(stream)
            for k, v in cfg.items():
                if k == "JOB_TEMPLATES" and v is not None:
                    parameters.append("-t '%s'" % v)
                elif k == "BRANCHES" and v is not None:
                    parameters.append("-b '%s'" % v)
                elif k == "JDKS" and v is not None:
                    parameters.append("-j '%s'" % v)
                elif k == "POM" and v is not None:
                    parameters.append("-p '%s'" % v)
                elif k == "MVN_GOALS" and v is not None:
                    parameters.append("-g '%s'" % v)
                elif k == "MVN_OPTS" and v is not None:
                    parameters.append("-o '%s'" % v)
                elif k == "DEPENDENCIES" and v is not None:
                    parameters.append("-d '%s'" % v)
                elif k == "ARCHIVE_ARTIFACTS" and v is not None:
                    parameters.append("-a '%s'" % v)

            parameters.append(project)
            cmd = " ".join(parameters)
            os.system(cmd)

        else:
            os.system("python scripts/jjb-init-project.py -z %s" % project)

##############
# Code Start #
##############

jjb_dir = "jjb"
all_projects = [d for d in os.listdir(jjb_dir)
                if os.path.isdir(os.path.join(jjb_dir, d))]
auto_update_projects = get_autoupdate_projects(jjb_dir, all_projects)
update_templates(auto_update_projects)
