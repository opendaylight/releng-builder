#!/usr/bin/python

import argparse
import os
import re
import sys

parser = argparse.ArgumentParser()
parser.add_argument("project", help="project")
parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
parser.add_argument("-o", "--mvn-opts", help="Maven Options")
args = parser.parse_args()

project = args.project
project_dir = os.path.join("jjb", project)
project_file = os.path.join(project_dir, "{}.yaml".format(project))
mvn_goals = args.mvn_goals  # Defaults to "clean install" if not passsed
mvn_opts = args.mvn_opts    # Defaults to blank if not passed

template_file = os.path.join("jjb", "job.yaml.template")

if not mvn_goals:
    mvn_goals = "-Dmaven.repo.local=$WORKSPACE/.m2repo -Dorg.ops4j.pax.url.mvn.localRepository=$WORKSPACE/.m2repo clean install"

if not mvn_opts:
    mvn_opts = "-Xmx1024m -XX:MaxPermSize=256m"

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
        if not re.match("\s*#", line):
            line = re.sub("MAVEN_GOALS", mvn_goals, line)
        if not re.match("\s*#", line):
            line = re.sub("MAVEN_OPTS", mvn_opts, line)
        outfile.write(line)
