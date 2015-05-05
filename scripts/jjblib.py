import argparse
import os


def parse_jjb_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("project", help="project")
    parser.add_argument("-c", "--conf", help="Config file")
    parser.add_argument("-d", "--dependencies",
                        help=("Project dependencies\n\n"
                              "A comma-seperated (no spaces) list of projects "
                              "your project depends on. "
                              "This is used to create an integration job that "
                              "will trigger when a dependent project-merge job "
                              "is built successfully.\n\n"
                              "Example: aaa,controller,yangtools"))
    parser.add_argument("-t", "--templates", help="Job templates to use")
    parser.add_argument("-b", "--branches", help="Git Branches to build")
    parser.add_argument("-j", "--jdks", help="JDKs to build against (for verify jobs)")  # noqa
    parser.add_argument("-p", "--pom", help="Path to pom.xml to use in Maven build"
                                            "(Default: pom.xml")
    parser.add_argument("-g", "--mvn-goals", help="Maven Goals")
    parser.add_argument("-o", "--mvn-opts", help="Maven Options")
    parser.add_argument("-a", "--archive-artifacts",
                        help="Comma-seperated list of patterns of artifacts to "
                             "archive on build completion. "
                             "See: http://ant.apache.org/manual/Types/fileset.html")  # noqa
    parser.add_argument("-z", "--no-cfg", action="store_true",
                        help=("Disable initializing the project.cfg file."))
    return parser.parse_args()


def create_template_config(project_dir, args):
    cfg_string = []

    if args.templates:
        cfg_string.append("JOB_TEMPLATES: %s" % args.templates)
    if args.branches:
        cfg_string.append("BRANCHES: %s" % args.branches)
    if args.jdks:
        cfg_string.append("JDKS: %s" % args.jdks)
    if args.pom:
        cfg_string.append("POM: %s" % args.pom)
    if args.mvn_goals:
        cfg_string.append("MAVEN_GOALS: %s" % args.mvn_goals)
    if args.mvn_opts:
        cfg_string.append("MAVEN_OPTS: %s" % args.mvn_opts)
    if args.dependencies:
        cfg_string.append("DEPENDENCIES: %s" % args.dependencies)
    if args.archive_artifacts:
        cfg_string.append("ARCHIVE: %s" % args.archive_artifacts)

    print("Creating %s.cfg file" % args.project)
    cfg_file = os.path.join(project_dir, "%s.cfg" % args.project)
    with open(cfg_file, "w") as outstream:
        cfg = "\n".join(cfg_string)
        outstream.write(cfg)
