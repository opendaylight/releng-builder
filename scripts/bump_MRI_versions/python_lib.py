def find_highest_revision(revisions):
    # convert list of strings to list of tuples
    converted_items = [tuple(map(int, item.split('.'))) for item in revisions]
    biggest_item = max(converted_items, key=lambda x: x)
    biggest_version = '.'.join(str(x) for x in biggest_item)
    return biggest_version