#!/usr/bin/python

import os

def get_autoupdate_projects(jjb_dir, projects):
    """Get list of projects that should be autoupdated"""
    project_list = []
    for project in projects:
        template = os.path.join(jjb_dir, project, "{}.yaml".format(project))
        if os.path.isfile(template):
            with open(template, 'r') as f:
                first_line = f.readline()
            if first_line.startswith("# REMOVE THIS LINE IF"):
                project_list.append(project)

    return project_list

def update_templates(projects):
    for project in projects:
        os.system("python scripts/jjb-init-project.py {}".format(project))

##############
# Code Start #
##############

jjb_dir = "jjb"
all_projects = [ d for d in os.listdir(jjb_dir)
                    if os.path.isdir(os.path.join(jjb_dir, d)) ]
auto_update_projects = get_autoupdate_projects(jjb_dir, all_projects)
update_templates(auto_update_projects)
