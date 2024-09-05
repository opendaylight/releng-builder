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

from collections import UserString

import yaml

from .errors import JenkinsJobsException
from .position import Pos


class LocDict(dict):
    """dict implementation with added source position information"""

    def __init__(self, value=None, pos=None, key_pos=None, value_pos=None):
        super().__init__(value or [])
        self.pos = pos
        self.key_pos = key_pos or {}  # key -> key pos.
        self.value_pos = value_pos or {}  # key -> value pos.

    def item_with_pos(self, key):
        value = self[key]  # KeyError is propagated from here.
        key_pos = self.key_pos.get(key)
        value_pos = self.value_pos.get(key)
        return (value, key_pos, value_pos)

    def pop_loc_string(self, key, default_value):
        value = super().pop(key, default_value)
        if type(value) is str:
            return LocString(value, self.value_pos.get(key))
        else:
            return value

    def pop_required_loc_string(self, name):
        try:
            value = self.pop(name)
        except KeyError:
            raise JenkinsJobsException(
                f"Missing required element: {name!r}",
                pos=self.pos,
            )
        return LocString(value, self.value_pos.get(name))

    def pop_required_element(self, name):
        try:
            return self.pop(name)
        except KeyError:
            raise JenkinsJobsException(
                f"Missing required element: {name!r}",
                pos=self.pos,
            )

    def copy(self):
        return LocDict(self, self.pos, self.key_pos, self.value_pos)

    def copy_with(self, value):
        return LocDict(value, self.pos, self.key_pos, self.value_pos)

    def __setitem__(self, key, value):
        if type(value) is LocString:
            super().__setitem__(key, str(value))
            self.value_pos[key] = value.pos
        else:
            super().__setitem__(key, value)

    def set_item(self, key, value, key_pos, value_pos):
        self[key] = value
        if key_pos:
            self.key_pos[key] = key_pos
        if value_pos:
            self.value_pos[key] = value_pos

    @classmethod
    def merge(cls, *args, pos=None):
        result = LocDict(pos=pos)
        for d in args:
            result.update(d)
            if type(d) is cls:
                result.key_pos.update(d.key_pos)
                result.value_pos.update(d.value_pos)
        return result

    def update(self, d):
        super().update(d)
        if type(d) is LocDict:
            self.key_pos.update(d.key_pos)
            self.value_pos.update(d.value_pos)


class LocList(list):
    """list implementation with added source position information"""

    def __init__(self, value=None, pos=None, value_pos=None):
        if value is None:
            value = []
        super().__init__(value)
        self.pos = pos
        self.value_pos = value_pos or [None for _ in value]  # Value pos list.

    def copy(self):
        return LocList(self, self.pos, self.value_pos)


class LocString(UserString):
    """str implementation with added source position information"""

    def __init__(self, value="", pos=None):
        super().__init__(value)
        self.pos = pos


class LocLoader(yaml.Loader):
    """Load YAML and store source position information"""

    def __init__(self, stream, file_path, line_ofs=0, column_ofs=0):
        super().__init__(stream)
        if file_path:
            # Override one set by yaml Reader. Used to construct marks.
            self.name = file_path
        self._line_ofs = line_ofs
        self._column_ofs = column_ofs

    def pos_from_node(self, node):
        return Pos.from_node(node, self._line_ofs, self._column_ofs)

    def construct_yaml_map(self, node):
        data = LocDict(pos=self.pos_from_node(node))
        yield data
        value = self.construct_mapping(node)
        data.update(value)
        data.key_pos.update(
            {
                key_node.value: self.pos_from_node(key_node)
                for key_node, value_node in node.value
            }
        )
        data.value_pos.update(
            {
                key_node.value: self.pos_from_node(value_node)
                for key_node, value_node in node.value
            }
        )

    def construct_yaml_seq(self, node):
        data = LocList(pos=self.pos_from_node(node))
        yield data
        data.extend(self.construct_sequence(node))
        data.value_pos.extend(self.pos_from_node(item_node) for item_node in node.value)


LocLoader.add_constructor("tag:yaml.org,2002:map", LocLoader.construct_yaml_map)
LocLoader.add_constructor("tag:yaml.org,2002:seq", LocLoader.construct_yaml_seq)
