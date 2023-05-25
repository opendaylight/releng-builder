# Copyright (c) 2023 PANTHEON.tech s.r.o. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html

"""Library calls for branch cutting a new stable release."""

# modify this dir for pick up project from there
bumping_dir = "repos"


def find_highest_revision(revisions):
    """Return bigger versions in the tuple."""
    # convert list of strings to list of tuples
    converted_items = [tuple(map(int, item.split("."))) for item in revisions]
    biggest_item = max(converted_items, key=lambda x: x)
    biggest_version = ".".join(str(x) for x in biggest_item)
    return biggest_version


def log_artifact(path, group_id=None, artifact_id=None, version=None, new_version=None):
    """Add filename and path, artifactId, versions to log."""
    log = ""
    log += "XML FILE: " + str(path) + "\n"
    # if none, printing feature update
    if group_id is None:
        log_line = ("path:", path, "VERSION:", version, "NEW VERSION:", new_version)
    # else printing artifact update
    else:
        log_line = (
            "groupId:",
            group_id.text,
            "ARTIFACT ID:",
            artifact_id.text,
            "VERSION:",
            version,
            "NEW VERSION:",
            new_version,
        )
    log += str(log_line) + "\n"
    log += str(100 * "*" + "\n")
    return log


def check_minor_version(version, new_version):
    """Take two version string and returns True if its same are the new version."""
    # compares the corresponding elements of the two version strings
    if any(
        int(elem_a) != int(elem_b)
        for elem_a, elem_b in zip(version.text.split("."), new_version.split("."))
    ):
        return True
    return False
