from functools import lru_cache

# cached_property was introduced in Python 3.8.
# TODO: Remove this file when support for Python 3.7 is dropped.
# Recipe from https://stackoverflow.com/a/19979379


def cached_property(fn):
    return property(lru_cache()(fn))
