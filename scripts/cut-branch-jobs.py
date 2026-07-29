# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2020 Thanh Ha
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
#
##############################################################################
"""Script for cutting new jobs when branching a new stable release."""

import argparse
from argparse import RawTextHelpFormatter
import copy
import fileinput
import io
import os
import shutil
import itertools
import re
import sys

try:
    import ruamel.yaml
    from ruamel.yaml.comments import TaggedScalar
    from ruamel.yaml.scalarstring import FoldedScalarString
except ModuleNotFoundError:
    print("ERROR: This script requires the package 'ruamel.yaml', please install it.")
    print(
        "If ruamel.yaml is not available in your system's package manager you"
        " can install from PyPi with:"
    )
    print("")
    print("    pip install --user ruamel.yaml")
    sys.exit(1)

yaml = ruamel.yaml.YAML()
yaml.allow_duplicate_keys = True
yaml.preserve_quotes = True
yaml.explicit_start = True
# Match the repo's prettier YAML style.
yaml.indent(mapping=2, sequence=4, offset=2)
# ponytail: never let the emitter rewrap a scalar, folded ones carry their own
# fold positions and the rest must stay exactly as the repo has them.
yaml.width = 4096


# ponytail: ruamel 0.18+ refuses to load a mapping with several "<<" keys and
# can only write one back, so hide them from the parser as plain keys and put
# them back on dump. JJB relies on multiple merges per job template.
MERGE_KEY = re.compile(r"^(\s*)<<:", re.M)
MERGE_PLACEHOLDER = re.compile(r"^(\s*)__merge_\d+__:", re.M)


def load_yaml(path):
    """Load a JJB YAML file, hiding merge keys from the parser."""
    count = itertools.count()
    with open(path) as f:
        text = MERGE_KEY.sub(
            lambda m: "{}__merge_{}__:".format(m.group(1), next(count)), f.read()
        )
    return yaml.load(text)


def _shift_comment(token):
    """Shift a comment 2 columns right so it survives the dedent in dump_yaml().

    A comment either carries its indentation inside its own text or is placed
    by the column of its start mark, so both need shifting.
    """
    lines = token.value.split("\n")
    if lines[0].lstrip().startswith("#"):
        token.start_mark.column += 2
    token.value = "\n".join(
        "  " + line if i and line.lstrip().startswith("#") else line
        for i, line in enumerate(lines)
    )


def _shift_comments(data, seen=None):
    """Shift every comment attached to data and its children."""
    if seen is None:
        seen = set()
    if id(data) in seen:
        return
    seen.add(id(data))
    ca = getattr(data, "ca", None)
    if ca is not None:
        groups = [ca.comment or [], [ca.end]] + list(ca.items.values())
        for group in groups:
            for token in group:
                for item in token if isinstance(token, list) else [token]:
                    if item is not None and id(item) not in seen:
                        seen.add(id(item))
                        _shift_comment(item)
    if isinstance(data, dict):
        children = data.values()
    elif isinstance(data, list):
        children = data
    else:
        return
    for child in children:
        _shift_comments(child, seen)


def folded_scalar(text, width=100):
    """Return text as a folded scalar wrapped at width columns."""
    folded = FoldedScalarString(text + "\n")
    positions = []
    start = 0
    length = 0
    for word in text.split(" "):
        if length and length + 1 + len(word) > width:
            positions.append(start - 1)  # the space becomes the line break
            length = len(word)
        else:
            length += (1 if length else 0) + len(word)
        start += len(word) + 1
    folded.fold_pos = positions
    return folded


def dump_yaml(data, path):
    """Write data to path keeping the repo's YAML indentation style."""
    _shift_comments(data)
    buf = io.StringIO()
    yaml.dump(data, buf)
    # ponytail: ruamel indents top level sequences too, strip the extra 2
    # columns so "- project:" stays at column 0 like the rest of the repo.
    with open(path, "w") as f:
        for line in buf.getvalue().splitlines(keepends=True):
            line = line[2:] if line.startswith("  ") else line
            f.write(MERGE_PLACEHOLDER.sub(r"\1<<:", line))


default_branch = "master"  # This is the primary dev branch of the project


def create_and_update_project_jobs(
    release_on_stable_branch, release_on_current_branch, job_dir
):
    """Create and update project build jobs for the current and next dev release.

    Project jobs are jobs defined in the project.yaml that have the same name
    the directory they are in.

    Only updates projects where the top project configuration has a name that
    is equivalent to the current release. For example project name
    "aaa-sulfur" would have a release that matches what was passed to
    release_on_stable_branch.
    """
    for directory in filter(
        lambda x: os.path.isdir(os.path.join(job_dir, x)), os.listdir(job_dir)
    ):
        try:
            data = load_yaml(
                os.path.join(job_dir, directory, "{}.yaml".format(directory))
            )

            # Only create new jobs if the top level project name matches
            # release_on_stable_branch variable
            if not data[0]["project"]["name"] == "{}-{}".format(
                directory, release_on_stable_branch
            ):
                continue

            # Create a new job for the next release on the default_branch
            new_job = copy.deepcopy(data[0])
            new_job["project"]["name"] = "{}-{}".format(
                directory, release_on_current_branch
            )
            new_job["project"]["branch"] = default_branch
            new_job["project"]["stream"] = "{}".format(release_on_current_branch)

            # Update exiting job for the new stable branch
            data[0]["project"]["branch"] = "stable/{}".format(release_on_stable_branch)

            data.insert(0, new_job)

            dump_yaml(
                data, os.path.join(job_dir, directory, "{}.yaml".format(directory))
            )
        except FileNotFoundError:  # If project.yaml file does not exist we can skip
            pass


def update_job_streams(release_on_stable_branch, release_on_current_branch, job_dir):
    """Update projects that have a stream variable that is a list.

    If a stream variable is a list that means the project likely has multiple
    maintainance branches supported.

    This function also does not support {project}.yaml files as parsing those
    are handled by other functions in this script.

    Only updates projects where the top stream in the list is equivalent to the
    current release. For example stream "sulfur" would have a release that
    matches what was passed to release_on_stable_branch.
    """
    for directory, _, job_files in os.walk(job_dir):
        if directory == job_dir:  # Top level files are not project jobs
            continue

        for job_file in job_files:
            # Projects may have non-yaml files in their repos so ignore them.
            if not job_file.endswith(".yaml"):
                continue

            # Ignore project.yaml files as they are not supported by this function.
            if job_file == "{}.yaml".format(os.path.basename(directory)):
                continue

            file_changed = False

            data = load_yaml(os.path.join(directory, job_file))

            for project in data:
                streams = project.get("project", {}).get("stream", None)

                if not isinstance(streams, list):  # We only support lists streams
                    continue

                # Skip if the stream does not match
                # release_on_stable_branch in the first item
                if not streams[0].get(release_on_stable_branch, None):
                    continue

                # Only cut a stream that still builds from the dev branch
                if streams[0][release_on_stable_branch].get("branch") != default_branch:
                    continue

                # Create the next release stream
                new_stream = {}
                new_stream[release_on_current_branch] = copy.deepcopy(
                    streams[0].get(release_on_stable_branch)
                )

                # Values naming the release (eg. integration-test) follow
                # the stream they belong to. Values without the release
                # name are left untouched to keep their formatting.
                new_values = new_stream[release_on_current_branch]
                for key, value in new_values.items():
                    if isinstance(value, str) and release_on_stable_branch in value:
                        new_value = value.replace(
                            release_on_stable_branch, release_on_current_branch
                        )
                        if isinstance(value, FoldedScalarString):
                            new_value = FoldedScalarString(new_value)
                        new_values[key] = new_value

                # Update the previous release stream branch to
                # stable/{stream} instead of default_branch
                streams[0][release_on_stable_branch]["branch"] = "stable/{}".format(
                    release_on_stable_branch
                )

                streams.insert(0, new_stream)
                file_changed = True

            # Because we are looping every file we only want to save if we made changes.
            if file_changed:
                dump_yaml(data, os.path.join(directory, job_file))


def update_integration_csit_list(
    release_on_stable_branch, release_on_current_branch, job_dir
):
    """Update csit-*-list variables and files integration-test-jobs.yaml."""
    # ponytail: round-trip loading preserves unknown tags as TaggedScalar,
    # so no custom constructor is needed.

    integration_test_jobs_yaml = os.path.join(
        job_dir, "integration", "integration-test-jobs.yaml"
    )

    data = load_yaml(integration_test_jobs_yaml)

    for project in data:
        # Skip items that are not of "project" type
        if not project.get("project"):
            continue

        streams = project.get("project", {}).get("stream", None)

        # Skip projects that do not have a stream configured
        if not isinstance(streams, list):  # We only support lists streams
            continue

        # Skip if the stream does not match
        # release_on_current_branch in the first item
        if not streams[0].get(release_on_current_branch, None):
            continue

        # Update csit-list parameters for next release
        if streams[0][release_on_current_branch].get("csit-list"):
            update_stream = streams[0][release_on_current_branch]
            update_stream["csit-list"] = TaggedScalar(
                value="csit-jobs-{}.lst".format(release_on_current_branch),
                tag="!include:",
            )

        # Update csit-mri-list parameters for next release
        if streams[0][release_on_current_branch].get("csit-mri-list"):
            update_stream = streams[0][release_on_current_branch]
            update_stream["csit-mri-list"] = "{{csit-mri-list-{}}}".format(
                release_on_current_branch
            )

        # Update csit-weekly-list parameters for next release
        if streams[0][release_on_current_branch].get("csit-weekly-list"):
            update_stream = streams[0][release_on_current_branch]
            update_stream["csit-weekly-list"] = "{{csit-weekly-list-{}}}".format(
                release_on_current_branch
            )

        # Update csit-sanity-list parameters for next release
        if streams[0][release_on_current_branch].get("csit-sanity-list"):
            update_stream = streams[0][release_on_current_branch]
            update_stream["csit-sanity-list"] = "{{csit-sanity-list-{}}}".format(
                release_on_current_branch
            )

    dump_yaml(data, integration_test_jobs_yaml)

    # Update the csit-*-list variables in defaults.yaml

    defaults_yaml = os.path.join(job_dir, "defaults.yaml")

    data = load_yaml(defaults_yaml)

    defaults = data[0]["defaults"]
    for name in ("csit-mri-list", "csit-weekly-list", "csit-sanity-list"):
        previous = defaults.get("{}-{}".format(name, release_on_stable_branch))
        if previous is None:
            continue
        entries = " ".join(previous.split()).replace(
            release_on_stable_branch, release_on_current_branch
        )
        defaults["{}-{}".format(name, release_on_current_branch)] = folded_scalar(
            entries
        )

    dump_yaml(data, defaults_yaml)

    # Handle copying and updating the csit-*.lst files
    csit_file = "csit-jobs-{}.lst".format(release_on_stable_branch)
    src = os.path.join(job_dir, "integration", csit_file)
    dest = os.path.join(
        job_dir,
        "integration",
        csit_file.replace(release_on_stable_branch, release_on_current_branch),
    )
    shutil.copyfile(src, dest)
    with fileinput.FileInput(dest, inplace=True) as file:
        for line in file:
            print(
                line.replace(release_on_stable_branch, release_on_current_branch),
                end="",
            )


parser = argparse.ArgumentParser(
    description="""Creates & updates jobs for ODL projects when branch cutting.

    Example usage: python scripts/cut-branch.sh Phosphorus Sulfur jjb/

    ** If calling from tox the JOD_DIR is auto-detected so only pass the current
    and next release stream name. **
    """,
    formatter_class=RawTextHelpFormatter,
)
parser.add_argument(
    "release_on_stable_branch",
    metavar="RELEASE_ON_STABLE_BRANCH",
    type=str,
    help="The ODL release codename for the stable branch that was cut.",
)
parser.add_argument(
    "release_on_current_branch",
    metavar="RELEASE_ON_CURRENT_BRANCH",
    type=str,
    help="""The ODL release codename for the new {}
        (eg. Sulfur, Phosphorus).""".format(
        default_branch
    ),
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
release_on_current_branch = args.release_on_current_branch.lower()

create_and_update_project_jobs(
    release_on_stable_branch, release_on_current_branch, args.job_dir
)
update_job_streams(release_on_stable_branch, release_on_current_branch, args.job_dir)
update_integration_csit_list(
    release_on_stable_branch, release_on_current_branch, args.job_dir
)
