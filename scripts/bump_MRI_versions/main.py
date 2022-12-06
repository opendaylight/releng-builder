import requests, re, sys, getopt, os, git
import xml.etree.ElementTree as ET
from pathlib import Path
from bs4 import BeautifulSoup
from datetime import datetime
from python_lib import find_highest_revision


logs = ""
global repo

# retrieve args from command
def main(argv):
    global log, repo
    log = "N"
    repo = "aaa"
    try:
        opts, args = getopt.getopt(argv,"hl:r",["help", "log=","repo="])
    except getopt.GetoptError:
        print("wrong usage type -h or --help for help")
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h' or opt == '--help':
            print("Usage: python3 main.py [log] [repo]")
            print("[log] -l y/n or --log Y/N")
            print("[repo] -r aaa or -r odlparent or --repo mdsal or --repo netconf")
            sys.exit()
        elif opt in ("-l", "--log"):
            log = arg.upper()
        elif opt in ("-r", "--repo"):
            repo = arg
if __name__ == "__main__":
   main(sys.argv[1:])

# delete logs if -l Y
if log == "Y":
    os.system("rm -rf /logs/*")

#clone repo if repo dir not exist
repo_dir = f"repos/{repo}"
if not os.path.exists(repo_dir):
    print("Cloning repositpory please wait.")
    git_url =  f"https://git.opendaylight.org/gerrit/{repo}"
    git.Repo.clone_from(git_url, repo_dir)

def get_version_for_artifact(groupId, artifactId):
    global logs
    url = f'https://repo1.maven.org/maven2/org/opendaylight/{groupId}/{artifactId}/'
    print(url)
    logs += "NEW VERSION LINK: " + str(url) + "\n"
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


#get all xml files from repo_dir folder and extract values from groupId, artifactId, version tags
for path in Path(repo_dir).rglob('*.xml'):
    try:
        tree = ET.parse(path)
    except SyntaxError:
        pass
    root = tree.getroot()
    all_parent = root.findall('{http://maven.apache.org/POM/4.0.0}parent')
    if all_parent:
        for parent in all_parent:
            groupId = parent.find('{http://maven.apache.org/POM/4.0.0}groupId')
            artifactId = parent.find('{http://maven.apache.org/POM/4.0.0}artifactId')
            version = parent.find('{http://maven.apache.org/POM/4.0.0}version')
            if not "SNAPSHOT" in version.text :
                logs += "XML FILE: " + str(path) + "\n"
                new_version = get_version_for_artifact(groupId.text.split(".")[2], artifactId.text)
                log_line = ("PARENT-GROUP ID:", groupId.text , "ARTIFACT ID:", artifactId.text, "VERSION:", version.text, "NEW VERSION:", new_version)
                # print(log_line)
                logs += str(log_line) + "\n"
                logs += str(100 * "*" + "\n")

    all_dependencies = root.findall('{http://maven.apache.org/POM/4.0.0}dependencies')
    if all_dependencies:
        for dependency in all_dependencies:
            dependency_objects = dependency.findall('{http://maven.apache.org/POM/4.0.0}dependency')
            for object in dependency_objects:
                groupId = object.find('{http://maven.apache.org/POM/4.0.0}groupId')
                artifactId = object.find('{http://maven.apache.org/POM/4.0.0}artifactId')
                version = object.find('{http://maven.apache.org/POM/4.0.0}version')
                if "org.opendaylight" in groupId.text and version != None:
                    if not version.text == "${project.version}":
                        logs += "XML FILE: " + str(path) + "\n"
                        new_version = get_version_for_artifact(groupId.text.split(".")[2], artifactId.text)
                        log_line = ("DEPENDENCY-GROUP ID:", groupId.text , "ARTIFACT ID:", artifactId.text, "VERSION:", version.text, "NEW VERSION:", new_version)
                        logs += str(log_line) + "\n"
                        logs += str(100 * "*" + "\n")

if log == "Y":
    os.system("rm -rf logs/*")

os.system(f"cd logs &&  touch {repo}.log")
with open(f'logs/{repo}.log', 'w') as f:
    f.write(str(logs))