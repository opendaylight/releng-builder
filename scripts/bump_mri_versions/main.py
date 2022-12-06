# Copyright (c) 2023 PANTHEON.tech s.r.o. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html

import requests, re, python_lib
from pathlib import Path
from bs4 import BeautifulSoup
from lxml import etree



def get_version_for_artifact(groupId, artifactId):
    versions_list = []
    url = f'https://repo1.maven.org/maven2/org/opendaylight/{groupId}/{artifactId}/'
    response = requests.get(url).content
    soup = BeautifulSoup(response, 'html.parser')
    try:
        html_lines = str(soup.find_all('pre')[0]).splitlines()
    except IndexError:
        return "NOT FOUND"
    for line in html_lines:
        # Use a regular expression to find version
        pattern = re.compile(r'\d+\.\d+\.\d+')
        title = pattern.search(line)
        try:
            versions_list.append(title.group())
        except AttributeError:
            pass
    return python_lib.find_highest_revision(versions_list)


# get all xml files
for path in Path(python_lib.bumping_dir).rglob('*.xml'):
    if "pom.xml" or "feature.xml" in str(path):
        if "test/resources" not in str(path): # pass wrong xml files
            tree = etree.parse(path)
            root = tree.getroot()
            # update major and minor artifacts versions
            if "pom.xml" in str(path):
                prefix = "{" + root.nsmap[None] + "}"
                all_elements = tree.findall(f'.//{prefix}parent') + tree.findall(f'.//{prefix}dependency')
                for element in all_elements:
                    groupId = (element.find(f'{prefix}groupId'))
                    artifactId = (element.find(f'{prefix}artifactId'))
                    version = (element.find(f'{prefix}version'))
                    try:
                        if "org.opendaylight" in groupId.text and version != None:
                            if not version.text == "${project.version}" and not "SNAPSHOT" in version.text and not "@project.version@" in version.text:
                                # check major version and minor version
                                new_version = get_version_for_artifact(groupId.text.split(".")[2], artifactId.text)
                                if python_lib.check_minor_version(version, new_version):
                                    print(python_lib.log_artifact(path, groupId, artifactId, version.text, new_version))
                                    version.text = new_version
                                    tree.write(path, encoding="UTF-8", pretty_print=True, doctype='<?xml version="1.0" encoding="UTF-8"?>')
                    except AttributeError:
                        pass


            # update feature versions
            if "feature.xml" in str(path):
                print(path)
                prefix = "{" + root.nsmap[None] + "}"
                all_featuress = tree.findall(f'.//{prefix}feature')

                # feature versions add +1
                for feature in all_featuress:
                    try:
                        if feature.attrib["version"] and feature.attrib["version"] != "${project.version}":
                            current_version = feature.attrib["version"]
                            # workaround for float feature versions
                            nums = current_version[1:-1].split(',')
                            if "." in nums[0]:
                                nums[0] = str(round((float(nums[0]) + 0.01), 2))
                            else:
                                nums[0], nums[1] = str(int(nums[0]) + 1), str(int(nums[1])+1)
                            result = '[' + ','.join(nums) + ')'
                            feature.attrib["version"] = result
                            print(python_lib.log_artifact(path=path, version=current_version, new_version=result))
                            standalone = ''
                            if tree.docinfo.standalone:
                                standalone =' standalone="yes"'
                            tree.write(path, encoding="UTF-8", pretty_print=True, doctype=f'<?xml version="1.0" encoding="UTF-8"{standalone}?>')
                    except KeyError:
                        pass