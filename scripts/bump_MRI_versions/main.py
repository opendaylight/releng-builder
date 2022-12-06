from pathlib import Path
import xml.etree.ElementTree as ET
import requests
from bs4 import BeautifulSoup
from datetime import datetime
import re
from python_lib import find_highest_revision
from git import Repo
import sys, getopt, os


# retrieve args from command
def main(argv):
    global log, repo
    log = "N"
    repo = "aaa"
    try:
        opts, args = getopt.getopt(argv,"hl:m:v:",["help", "log=","models=", "validator="])
    except getopt.GetoptError:
        print("wrong usage type -h or --help for help")
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h' or opt == '--help':
            print("Usage: python3 main.py [log] [project]")
            sys.exit()
        elif opt in ("-l", "--log"):
            log = arg.upper()
        elif opt in ("-r", "--repo"):
            repo = arg
if __name__ == "__main__":
   main(sys.argv[1:])


#create empty list for store pom.xml files
xml_list = []

#clone repo if repo dir not exist
repo_dir = f"repos/{repo}"
if not os.path.exists(repo_dir):
    print("Cloning repositpory please wait.")
    git_url =  f"https://git.opendaylight.org/gerrit/{repo}"
    Repo.clone_from(git_url, repo_dir)


#get all xml files from /repos folder
for path in Path('repos').rglob('*.xml'):
    # Parse the XML file
    tree = ET.parse(path)

    # get the root element
    root = tree.getroot()

    # find the <groupId> element
    try:
        groupId = root.find('{http://maven.apache.org/POM/4.0.0}parent/{http://maven.apache.org/POM/4.0.0}groupId')
        # print the text value of the <groupId> element
        if groupId.text == "org.opendaylight.odlparent":
            xml_list.append(path)
        else:
            groupId = root.find('{http://maven.apache.org/POM/4.0.0}dependencyManagement/{http://maven.apache.org/POM/4.0.0}dependencies/{http://maven.apache.org/POM/4.0.0}dependency/{http://maven.apache.org/POM/4.0.0}groupId')
            if groupId.text == "org.opendaylight.infrautils" or groupId.text == "org.opendaylight.aaa":
                xml_list.append(path)
    except AttributeError:
        pass

for file in xml_list:
    print(file)
print(len(xml_list))

def get_version_for_artifact(groupId, artifactId):
    url = f'https://repo1.maven.org/maven2/org/opendaylight/{groupId}/{artifactId}/'
    print(url)
    response = requests.get(url).content
    soup = BeautifulSoup(response, 'html.parser')
    html_lines = str(soup.find_all('pre')[0]).splitlines()
    # [print(line) for line in html_lines]
    versions_list = []
    title_date_map = {}
    for string in html_lines:
        # Use a regular expression to find the title and date
        pattern = re.compile(r'\d+\.\d+\.\d+')
        title = pattern.search(string)
        date_regex = r'([0-9]{4}-[0-9]{2}-[0-9]{2})'
        # title = re.search(title_regex, string)
        date = re.search(date_regex, string)


        # Print the extracted title and date
        try:
            title_date_map[title.group()] = datetime.strptime(date.group(), '%Y-%m-%d')
            versions_list.append(title.group())
        except AttributeError:
            pass

    version = find_highest_revision(versions_list)
    print(version)

get_version_for_artifact("odlparent", "single-feature-parent")