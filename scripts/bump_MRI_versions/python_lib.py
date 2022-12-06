# Copyright (c) 2019 PANTHEON.tech s.r.o. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html

# modify this dir for pick up project from there
bumping_dir = f"repos"

def find_highest_revision(revisions):
    # convert list of strings to list of tuples
    converted_items = [tuple(map(int, item.split('.'))) for item in revisions]
    biggest_item = max(converted_items, key=lambda x: x)
    biggest_version = '.'.join(str(x) for x in biggest_item)
    return biggest_version

def log_artifact(path, groupId, artifactId, version, new_version):
    log = ""
    log += "XML FILE: " + str(path) + "\n"
    log_line = ("groupId:", groupId.text , "ARTIFACT ID:", artifactId.text, "VERSION:", version, "NEW VERSION:", new_version)
    log += str(log_line) + "\n"
    log += str(100 * "*" + "\n")
    return(log)

def check_minor_version(version, new_version):
    if int(new_version.split(".")[1]) != int(version.text.split(".")[1]) or int(new_version.split(".")[2]) != int(version.text.split(".")[2]):
        return True