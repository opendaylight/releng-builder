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

import os


def _is_project(path, directory):
    template = os.path.join(path, directory, "%s.yaml" % directory)
    if os.path.isfile(template):  # Project found
        with open(template, 'r') as f:
            first_line = f.readline()
        if first_line.startswith("# REMOVE THIS LINE IF"):
            return directory


def get_autoupdate_projects(jjb_dir, directories):
    """Get list of projects that should be auto-updated."""
    project_list = []

    for d in directories:
        project = _is_project(jjb_dir, d)
        if project:
            project_list.append(project)

        # Find sub-projects
        for sub_directory in os.listdir(os.path.join(jjb_dir, d)):
            if os.path.isdir(os.path.join(jjb_dir, d, sub_directory)):
                project = _is_project(os.path.join(jjb_dir, d), sub_directory)
                if project:
                    project_list.append("%s/%s" % (d, project))

    return project_list


def update_templates(projects):
    for project in projects:
        if project.find('/') >= 0:  # Meta project
            cfg_file = "jjb/%s/%s.cfg" % (project, project.rsplit('/', 1)[1])
        else:
            cfg_file = "jjb/%s/%s.cfg" % (project, project)
        os.system("python scripts/jjb-init-project.py %s -c %s" %
                  (project, cfg_file))

##############
# Code Start #
##############

jjb_dir = "jjb"
all_projects = [d for d in os.listdir(jjb_dir)
                if os.path.isdir(os.path.join(jjb_dir, d))]
auto_update_projects = get_autoupdate_projects(jjb_dir, all_projects)
update_templates(auto_update_projects)
