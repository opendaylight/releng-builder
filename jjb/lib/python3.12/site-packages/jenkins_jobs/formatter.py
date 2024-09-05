#!/usr/bin/env python
# Copyright (C) 2015 OpenStack, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Manage interpolation of JJB variables into template strings.

import _string
import logging
import re
from string import Formatter

from jinja2 import Undefined
from jinja2.exceptions import UndefinedError

from .errors import JenkinsJobsException

logger = logging.getLogger(__name__)


class CustomFormatter(Formatter):
    """
    Custom formatter to allow non-existing key references when formatting a
    string
    """

    _expr = r"""
        (?<!{){({{)*                # non-pair opening {
        (?:obj:)?                   # obj:
        (?P<key>\w+)                # key
        (?:\|(?P<default>[^}]*))?   # default fallback
        }(}})*(?!})                 # non-pair closing }
    """
    _matcher = re.compile(_expr, re.VERBOSE)
    _whole_matcher = re.compile(f"^{_expr}$", re.VERBOSE)

    def __init__(self, allow_empty=False):
        super().__init__()
        self.allow_empty = allow_empty

    def vformat(self, format_string, args, kwargs):
        # Special case of returning the object preserving it's type if the entire string
        # matches a single parameter.
        result = self._whole_matcher.match(format_string)
        if result is not None:
            try:
                value = kwargs[result.group("key")]
            except KeyError:
                pass
            else:
                if not isinstance(value, Undefined):
                    return value

        # handle multiple fields within string via a callback to re.sub()
        def re_replace(match):
            key = match.group("key")
            default = match.group("default")

            if default is not None:
                if key not in kwargs or isinstance(kwargs[key], Undefined):
                    return default
                else:
                    return "{%s}" % key
            return match.group(0)

        format_string = self._matcher.sub(re_replace, format_string)

        try:
            return super().vformat(format_string, args, kwargs)
        except (JenkinsJobsException, UndefinedError, ValueError) as x:
            if len(format_string) > 40:
                short_fmt = format_string[:80] + "..."
            else:
                short_fmt = format_string
            raise JenkinsJobsException(f"While formatting string {short_fmt!r}: {x}")

    def enum_required_params(self, format_string):
        def re_replace(match):
            key = match.group("key")
            return "{%s}" % key

        prepared_format_string = self._matcher.sub(re_replace, format_string)
        for literal_text, field_name, format_spec, conversion in self.parse(
            prepared_format_string
        ):
            if field_name is None:
                continue
            arg_used, rest = _string.formatter_field_name_split(field_name)
            if arg_used == "" or type(arg_used) is int:
                raise JenkinsJobsException(
                    f"Positional format arguments are not supported: {format_string!r}"
                )
            yield arg_used

    def enum_param_defaults(self, format_string):
        for match in self._matcher.finditer(format_string):
            key = match.group("key")
            default = match.group("default")
            if default is not None:
                yield (key, default)

    def get_value(self, key, args, kwargs):
        try:
            return super().get_value(key, args, kwargs)
        except KeyError:
            if self.allow_empty:
                logger.debug(
                    "Found uninitialized key %s, replaced with empty string", key
                )
                return ""
            raise JenkinsJobsException(f"Missing parameter: {key!r}")


def enum_str_format_required_params(format, pos):
    formatter = CustomFormatter()
    try:
        yield from formatter.enum_required_params(str(format))
    except JenkinsJobsException as x:
        raise x.with_pos(pos)


def enum_str_format_param_defaults(format):
    formatter = CustomFormatter()
    yield from formatter.enum_param_defaults(str(format))
