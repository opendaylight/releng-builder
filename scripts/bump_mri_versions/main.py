# Copyright (c) 2023 PANTHEON.tech s.r.o. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html
"""Main function for branch cutting a new stable release."""

import re
import requests
import python_lib

# pylint: disable=wrong-import-order
from pathlib import Path
from bs4 import BeautifulSoup

# from lxml import etree
from defusedxml import lxml as etree

"""Get the version from the groupId and artifactId."""


def get_version_for_artifact(group_id, artifact_id):
    """Retrive version number from the groupId and artifactId."""
    versions_list = []
    url = f"https://repo1.maven.org/maven2/org/opendaylight/{group_id}/{artifact_id}/"
    response = requests.get(url, timeout=5).content
    soup = BeautifulSoup(response, "html.parser")
    try:
        html_lines = str(soup.find_all("pre")[0]).splitlines()
    except IndexError:
        return "NOT FOUND"
    for line in html_lines:
        # Use a regular expression to find version
        pattern = re.compile(r"\d+\.\d+\.\d+")
        title = pattern.search(line)
        try:
            versions_list.append(title.group())
        except AttributeError:
            pass
    return python_lib.find_highest_revision(versions_list)


# get all xml files
for path in Path(python_lib.bumping_dir).rglob("*.xml"):
    if "test/resources" in str(path):
        continue
    parser = etree.XMLParser(resolve_entities=False, no_network=True)
    tree = etree.parse(path, parser)
    root = tree.getroot()
    # update major and minor artifacts versions
    if "pom.xml" in str(path):
        prefix = "{" + root.nsmap[None] + "}"
        # line above can trigger a 'KeyError: None' outside pom.xml and
        # feature.xml files.
        all_elements = tree.findall(f".//{prefix}parent") + tree.findall(
            f".//{prefix}dependency"
        )
        for element in all_elements:
            group_id_elem = element.find(f"{prefix}groupId")
            artifact_id_elem = element.find(f"{prefix}artifactId")
            version = element.find(f"{prefix}version")
            try:
                if "org.opendaylight" in group_id_elem.text and version is not None:
                    # skip artifacts containing items in skipped list
                    skipped = ["${project.version}", "SNAPSHOT", "@project.version@"]
                    if not any(x in version.text for x in skipped):
                        new_version = get_version_for_artifact(
                            group_id_elem.text.split(".")[2], artifact_id_elem.text
                        )
                        if python_lib.check_minor_version(version, new_version):
                            print(
                                python_lib.log_artifact(
                                    path,
                                    group_id_elem,
                                    artifact_id_elem,
                                    version.text,
                                    new_version,
                                )
                            )
                            version.text = new_version
                            tree.write(
                                path,
                                encoding="UTF-8",
                                pretty_print=True,
                                doctype='<?xml version="1.0" encoding="UTF-8"?>',
                            )
            except AttributeError:
                pass
    # update feature versions
    if "feature.xml" in str(path):
        prefix = "{" + root.nsmap[None] + "}"
        # line above can trigger a 'KeyError: None' outside pom.xml and
        # feature.xml files.
        all_features = tree.findall(f".//{prefix}feature")
        # feature versions add +1
        for feature in all_features:
            try:
                if (
                    feature.attrib["version"]
                    and feature.attrib["version"] != "${project.version}"
                ):
                    current_version = feature.attrib["version"]
                    # workaround for float feature versions
                    nums = current_version[1:-1].split(",")
                    if "." in nums[0]:
                        nums[0] = str(round((float(nums[0]) + 0.01), 2))
                    else:
                        nums[0] = str(int(nums[0]) + 1)
                        nums[1] = str(int(nums[1]) + 1)
                    result = "[" + ",".join(nums) + ")"
                    feature.attrib["version"] = result
                    print(
                        python_lib.log_artifact(
                            path=path, version=current_version, new_version=result
                        )
                    )
                    standalone = ""
                    if tree.docinfo.standalone:
                        standalone = ' standalone="yes"'
                    tree.write(
                        path,
                        encoding="UTF-8",
                        pretty_print=True,
                        doctype=f'<?xml version="1.0" encoding="UTF-8"{standalone}?>',
                    )
            except KeyError:
                pass
