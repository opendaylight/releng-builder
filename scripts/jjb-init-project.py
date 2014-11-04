#!/usr/bin/python

import argparse
import os
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument("project", help="project")
parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
parser.add_argument("-p", "--mvn-opts", help="Maven Options")
args = parser.parse_args()

project = args.project
project_dir = os.path.join("jjb", project)
project_file = os.path.join(project_dir, "{}.yaml".format(project))
mvn_goals = args.mvn_goals  # Defaults to "clean install" if not passsed
mvn_opts = args.mvn_opts    # Defaults to blank if not passed

template_file = os.path.join("jjb", "job.yaml.template")

if not mvn_goals:
    mvn_goals = "clean install"

# Create project directory if it doesn't exist
if not os.path.exists(project_dir):
    os.makedirs(project_dir)

print("project: {}\ngoals: {}\noptions: {}".format(
    project,
    mvn_goals,
    mvn_opts))

# Create initial project YAML file
with open(template_file, "r") as infile, open(project_file, "w") as outfile:
    for line in infile:
        if not re.match("\s*#", line):
            line = re.sub("PROJECT", project, line)
        outfile.write(line)
