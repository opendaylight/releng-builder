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

import sys
import yaml

if sys.version_info >= (3, 8):
    from functools import cached_property
else:
    from .cached_property import cached_property


LINE_SEPARATORS = "\0\r\n\x85\u2028\u2029"
WHITESPACE_CHARS = " \t"


class Pos:
    @classmethod
    def from_node(cls, node, line_ofs=0, column_ofs=0):
        mark = node.start_mark
        return cls(mark, mark.name, mark.line + line_ofs, mark.column + column_ofs)

    @classmethod
    def from_file(cls, path, text):
        mark = yaml.Mark(str(path), 0, 0, 0, text, 0)
        return cls(mark, path, 0, 0)

    def __init__(self, mark, path, line, column):
        self._mark = mark
        self.path = path
        self.line = line  # Starts from 0.
        self.column = column  # Starts from 0.

    def __repr__(self):
        return f"<Pos {self.path}:{self.line}:{self.column}>"

    def with_offset(self, line_ofs=0, column_ofs=0):
        line_ptr = self._move_ptr_by_lines(line_ofs)
        ptr = line_ptr + column_ofs
        mark = self._clone_mark(self._mark, ptr)
        if line_ofs:
            column = column_ofs  # Start from new line.
        else:
            column = self.column + column_ofs
        return Pos(mark, self.path, self.line + line_ofs, column)

    def with_contents_start(self):
        ptr = self._mark.pointer
        buf = self._mark.buffer
        while (
            ptr < len(buf)
            and buf[ptr] not in LINE_SEPARATORS
            and buf[ptr] in WHITESPACE_CHARS
        ):
            ptr += 1
        mark = self._clone_mark(self._mark, ptr)
        return Pos(mark, self.path, self.line, self.column + ptr - self._mark.pointer)

    @cached_property
    def snippet(self):
        return self._mark.get_snippet(max_length=100)

    @cached_property
    def body(self):
        return self._mark.buffer[self._mark.pointer :]

    def _clone_mark(self, mark, ptr):
        return yaml.Mark(
            mark.name,
            mark.index,
            mark.line,
            mark.column,
            mark.buffer,
            ptr,
        )

    def _move_ptr_by_lines(self, line_ofs):
        ptr = self._mark.pointer
        buf = self._mark.buffer
        while line_ofs > 0 and ptr < len(buf):
            if buf[ptr] in LINE_SEPARATORS:
                line_ofs -= 1
            ptr += 1
        return ptr
