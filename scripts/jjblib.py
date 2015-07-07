import argparse
import collections
import os

import yaml


def parse_jjb_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("project", help="project")
    parser.add_argument("-c", "--conf", help="Config file")
    parser.add_argument("-d", "--dependencies",
                        help=("Project dependencies\n\n"
                              "A comma-seperated (no spaces) list of projects "
                              "your project depends on. "
                              "This is used to create an integration job that "
                              "will trigger when a dependent project-merge "
                              "job is built successfully.\n\n"
                              "Example: aaa,controller,yangtools"))
    parser.add_argument("-t", "--templates", help="Job templates to use")
    parser.add_argument("-s", "--streams",
                        help="Release streams to fill with default options")
    parser.add_argument("-p", "--pom", help="Path to pom.xml to use in Maven "
                                            "build (Default: pom.xml")
    parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
    parser.add_argument("-o", "--mvn-opts", help="Maven Options")
    parser.add_argument("-a", "--archive-artifacts",
                        help="Comma-seperated list of patterns of artifacts "
                             "to archive on build completion. "
                             "See: http://ant.apache.org/manual/Types/fileset.html")  # noqa
    return parser.parse_args()


STREAM_DEFAULTS = collections.OrderedDict([
    ("beryllium", {"branch": "master", "jdks": "openjdk7"}),
    ("stable-lithium", {"branch": "stable/lithium", "jdks": "openjdk7"}),
    ("stable-helium", {"branch": "stable/helium", "jdks": "openjdk7"}),
])


def create_template_config(project_dir, args):
    cfg_data = dict()

    if args.templates:
        cfg_data["JOB_TEMPLATES"] = args.templates

    if args.streams:
        stream_list = list()
        for stream in args.streams.split(","):
            stream_list.append({stream: STREAM_DEFAULTS[stream]})
        cfg_data["STREAMS"] = stream_list

    if args.pom:
        cfg_data["POM"] = args.pom

    if args.mvn_goals:
        cfg_data["MAVEN_GOALS"] = args.mvn_goals

    if args.mvn_opts:
        cfg_data["MAVEN_OPTS"] = args.mvn_opts

    if args.dependencies:
        cfg_data["DEPENDENCIES"] = args.dependencies

    if args.archive_artifacts:
        cfg_data["ARCHIVE"] = args.archive_artifacts

    if cfg_data:
        # Create project directory if it doesn't exist
        if not os.path.exists(project_dir):
            os.makedirs(project_dir)

        print("Creating %s.cfg file" % args.project)
        cfg_file = os.path.join(project_dir, "%s.cfg" % args.project)

        with open(cfg_file, "w") as outstream:
            outstream.write(yaml.dump(cfg_data, default_flow_style=False))
