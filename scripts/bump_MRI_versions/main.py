# Copyright (c) 2019 PANTHEON.tech s.r.o. All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html

import requests, re
from pathlib import Path
from bs4 import BeautifulSoup
from datetime import datetime
from python_lib import find_highest_revision, log_artifact, check_minor_version
from lxml import etree


global repo
repo="aaa"
repo_dir = f"repos/{repo}"

def get_version_for_artifact(groupId, artifactId):
    global logs
    url = f'https://repo1.maven.org/maven2/org/opendaylight/{groupId}/{artifactId}/'
    # logs += "NEW VERSION LINK: " + str(url) + "\n"
    response = requests.get(url).content
    soup = BeautifulSoup(response, 'html.parser')
    try:
        html_lines = str(soup.find_all('pre')[0]).splitlines()
    except IndexError:
        return "NOT FOUND"
    versions_list = []
    title_date_map = {}
    for string in html_lines:
        # Use a regular expression to find the title and date
        pattern = re.compile(r'\d+\.\d+\.\d+')
        title = pattern.search(string)
        date_regex = r'([0-9]{4}-[0-9]{2}-[0-9]{2})'
        date = re.search(date_regex, string)
        try:
            title_date_map[title.group()] = datetime.strptime(date.group(), '%Y-%m-%d')
            versions_list.append(title.group())
        except AttributeError:
            pass
    return find_highest_revision(versions_list)


# get all xml files
for path in Path(repo_dir).rglob('*.xml'):
    if "pom.xml" in str(path):
        tree = etree.parse(path)
        prefix = "{http://maven.apache.org/POM/4.0.0}"
        all_elements = tree.findall(f'.//{prefix}parent') + tree.findall(f'.//{prefix}dependency')
        for element in all_elements:
            groupId = (element.find(f'{prefix}groupId'))
            artifactId = (element.find(f'{prefix}artifactId'))
            version = (element.find(f'{prefix}version'))
            try:
                if "org.opendaylight" in groupId.text and version != None:
                    if not version.text == "${project.version}" and not "SNAPSHOT" in version.text and not "@project.version@" in version.text:
                        # check major version
                        new_version = get_version_for_artifact(groupId.text.split(".")[2], artifactId.text)
                        print(groupId.text, artifactId.text, version.text, new_version)
                        if int(new_version.split(".")[0]) == int(version.text.split(".")[0]):
                            # check minor version and patch version
                            if check_minor_version(version, new_version):
                                print(log_artifact(path, groupId, artifactId, version.text, new_version))
                                version.text = new_version
                                tree.write(path, encoding="UTF-8", pretty_print=True, doctype='<?xml version="1.0" encoding="UTF-8"?>')
            except AttributeError:
                pass