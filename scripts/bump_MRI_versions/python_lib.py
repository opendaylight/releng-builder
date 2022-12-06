from xml.etree import ElementTree

def find_highest_revision(revisions):
    # convert list of strings to list of tuples
    converted_items = [tuple(map(int, item.split('.'))) for item in revisions]
    biggest_item = max(converted_items, key=lambda x: x)
    biggest_version = '.'.join(str(x) for x in biggest_item)
    return biggest_version


def get_namespaces(my_schema):
    my_namespaces = dict([
        node for _, node in ElementTree.iterparse(
            my_schema, events=['start-ns'])])
    return my_namespaces

def log_artifact(path, groupId, artifactId, version, new_version):
    log = ""
    log += "XML FILE: " + str(path) + "\n"
    log_line = ("groupId:", groupId.text , "ARTIFACT ID:", artifactId.text, "VERSION:", version, "NEW VERSION:", new_version)
    log += str(log_line) + "\n"
    log += str(100 * "*" + "\n")
    return(log)
