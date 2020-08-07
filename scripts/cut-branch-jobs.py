"""Script for cutting new jobs when branching a new stable release."""

import argparse
from argparse import RawTextHelpFormatter
import copy
import os
import ruamel.yaml

yaml = ruamel.yaml.YAML()
yaml.allow_duplicate_keys = True
yaml.preserve_quotes = True


def create_and_update_project_jobs(
    release_on_stable_branch, release_on_master_branch, job_dir
):
    """Create and update project build jobs for the current and next dev release.

    Project jobs are jobs defined in the project.yaml that have the same name
    the directory they are in.

    Only updates projects where the top project configuration has a name that
    is equivalent to the current release. For example project name
    "aaa-silicon" would have a release that matches what was passed to
    release_on_stable_branch.
    """
    for directory in filter(
        lambda x: os.path.isdir(os.path.join(job_dir, x)), os.listdir(job_dir)
    ):
        try:
            with open(
                os.path.join(job_dir, directory, "{}.yaml".format(directory)), "r"
            ) as f:
                data = yaml.load(f)

                # Only create new jobs if the top level project name matches
                # release_on_stable_branch variable
                if not data[0]["project"]["name"] == "{}-{}".format(
                    directory, release_on_stable_branch
                ):
                    continue

                # Create a new job for the next release on the master branch
                new_job = copy.deepcopy(data[0])
                new_job["project"]["name"] = "{}-{}".format(
                    directory, release_on_master_branch
                )
                new_job["project"]["branch"] = "master"
                new_job["project"]["stream"] = "{}".format(release_on_master_branch)

                # Update exiting job for the new stable branch
                data[0]["project"]["branch"] = "stable/{}".format(
                    release_on_stable_branch
                )

                data.insert(0, new_job)

            with open(
                os.path.join(job_dir, directory, "{}.yaml".format(directory)), "w"
            ) as f:
                stream = ruamel.yaml.round_trip_dump(data)
                f.write("---\n")
                f.write(stream)
        except FileNotFoundError:  # If project.yaml file does not exist we can skip
            pass


def update_job_streams(release_on_stable_branch, release_on_master_branch, job_dir):
    """Update projects that have a stream variable that is a list.

    If a stream variable is a list that means the project likely has multiple
    maintainance branches supported.

    This function also does not support {project}.yaml files as parsing those
    are handled by other functions in this script.

    Only updates projects where the top stream in the list is equivalent to the
    current release. For example stream "silicon" would have a release that
    matches what was passed to release_on_stable_branch.
    """
    for directory in filter(
        lambda d: os.path.isdir(os.path.join(job_dir, d)), os.listdir(job_dir)
    ):
        for job_file in filter(
            lambda f: os.path.isfile(os.path.join(job_dir, directory, f)),
            os.listdir(os.path.join(job_dir, directory)),
        ):

            # Projects may have non-yaml files in their repos so ignore them.
            if not job_file.endswith(".yaml"):
                continue

            # Ignore project.yaml files as they are not supported by this function.
            if job_file == "{}.yaml".format(directory):
                continue

            file_changed = False

            with open(os.path.join(job_dir, directory, job_file), "r") as f:
                data = yaml.load(f)

                for project in data:
                    streams = project.get("project", {}).get("stream", None)

                    if not isinstance(streams, list):  # We only support lists streams
                        continue

                    # Skip if the stream does not match
                    # release_on_stable_branch in the first item
                    if not streams[0].get(release_on_stable_branch, None):
                        continue

                    # Create the next release stream
                    new_stream = {}
                    new_stream[release_on_master_branch] = copy.deepcopy(
                        streams[0].get(release_on_stable_branch)
                    )

                    # Update the previous release stream branch to
                    # stable/{stream} instead of master
                    streams[0][release_on_stable_branch]["branch"] = "stable/{}".format(
                        release_on_stable_branch
                    )

                    streams.insert(0, new_stream)
                    file_changed = True

            # Because we are looping every file we only want to save if we made changes.
            if file_changed:
                with open(os.path.join(job_dir, directory, job_file), "w") as f:
                    stream = ruamel.yaml.round_trip_dump(data)
                    f.write("---\n")
                    f.write(stream)


parser = argparse.ArgumentParser(
    description="""Creates & updates jobs for ODL projects when branch cutting.

    Example usage: python scripts/cut-branch.sh Silicon Phosphorus jjb/

    ** If calling from tox the JOD_DIR is auto-detected so only pass the current
    and next release stream name. **
    """,
    formatter_class=RawTextHelpFormatter
)
parser.add_argument(
    "release_on_stable_branch",
    metavar="RELEASE_ON_STABLE_BRANCH",
    type=str,
    help="The ODL release codename for the stable branch that was cut.",
)
parser.add_argument(
    "release_on_master_branch",
    metavar="RELEASE_ON_MASTER_BRANCH",
    type=str,
    help="""The ODL release codename for the new master branch
        (eg. Magnesium, Aluminium, Silicon).""",
)
parser.add_argument(
    "job_dir",
    metavar="JOB_DIR",
    type=str,
    help="Path to the directory containing JJB config.",
)
args = parser.parse_args()

# We only handle lower release codenames
release_on_stable_branch = args.release_on_stable_branch.lower()
release_on_master_branch = args.release_on_master_branch.lower()

create_and_update_project_jobs(
    release_on_stable_branch, release_on_master_branch, args.job_dir
)
update_job_streams(release_on_stable_branch, release_on_master_branch, args.job_dir)
