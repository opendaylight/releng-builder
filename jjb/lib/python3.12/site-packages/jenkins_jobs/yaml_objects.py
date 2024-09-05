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

# Provides local yaml parsing classes and extends yaml module.

"""Custom application specific yamls tags are supported to provide
enhancements when reading yaml configuration.

Action Tags
^^^^^^^^^^^

These allow manipulation of data being stored in one layout in the source
yaml for convenience and/or clarity, to another format to be processed by
the targeted module instead of requiring all modules in JJB being capable
of supporting multiple input formats.

The tag ``!join:`` will treat the first element of the following list as
the delimiter to use, when joining the remaining elements into a string
and returning a single string to be consumed by the specified module option.

This allows users to maintain elements of data in a list structure for ease
of review/maintenance, and have the yaml parser convert it to a string for
consumption as any argument for modules. The main expected use case is to
allow for generic plugin data such as shell properties to be populated from
a list construct which the yaml parser converts to a single string, instead
of trying to support this within the module code which would require a
templating engine similar to Jinja.

Generic Example:

    .. literalinclude:: /../../tests/loader/fixtures/joinlists.yaml


Environment Inject:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/string_join.yaml


While this mechanism can also be used items where delimiters are supported by
the module, that should be considered a bug that the existing code doesn't
handle being provided a list and delimiter to perform the correct conversion
for you. Should you discover a module that takes arguments with delimiters and
the existing JJB codebase does not handle accepting lists, then this can be
used as a temporary solution in place of using very long strings:

Extended Params Example:

    .. literalinclude::
        /../../tests/parameters/fixtures/extended-choice-param-full.yaml


Inclusion Tags
^^^^^^^^^^^^^^

These allow inclusion of arbitrary files as a method of having blocks of data
managed separately to the yaml job configurations. A specific usage of this is
inlining scripts contained in separate files, although such tags may also be
used to simplify usage of macros or job templates.

The tag ``!include:`` will treat the following string as file which should be
parsed as yaml configuration data.

Example:

    .. literalinclude:: /../../tests/loader/fixtures/include001.yaml

    contents of include001.yaml.inc:

    .. literalinclude:: /../../tests/loader/fixtures/include001.yaml.inc


The tag ``!include-raw-expand:`` will treat the given string or list of strings
as filenames to be opened as one or more data blob, which should be read into
the calling yaml construct without any further parsing. Any data in a file
included through this tag, will be treated as string data.

It will expand variables inside the file. If your file contains curly braces,
you should double them. Or, you can use tag ``!include-raw-verbatim:``, which
does not substitute variables.

Examples:

    .. literalinclude::
        /../../tests/loader/fixtures/include-raw-verbatim-template.yaml

    contents of include-raw-hello-world.sh:

        .. literalinclude::
            /../../tests/loader/fixtures/include-raw-hello-world.sh

    contents of include-raw-vars.sh:

        .. literalinclude::
            /../../tests/loader/fixtures/include-raw-vars.sh

    Using a list of files:

    .. literalinclude::
        /../../tests/loader/fixtures/include-raw-verbatim-multi-template.yaml


For all the multi file includes, the files are simply appended using a newline
character.


You can also use variables in included file paths.

Example:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/lazy-load-jobs001.yaml

    with variable substitution inside included files:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/lazy-load-with-variables.yaml

    using a list of files:

    .. literalinclude::
        /../../tests/yamlparser/job_fixtures/lazy-load-jobs-multi001.yaml


The tag ``!include-jinja2:`` will treat the given string or list of strings as
filenames to be opened as Jinja2 templates, which should be rendered to a
string and included in the calling YAML construct.  (This is analogous to the
templating that will happen with ``!include-raw``.)

Examples:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/jinja01.yaml

    contents of jinja01.yaml.inc:

        .. literalinclude:: /../../tests/yamlparser/job_fixtures/jinja01.yaml.inc


The tag ``!j2:`` takes a string and treats it as a Jinja2 template.  It will be
rendered (with the variables in that context) and included in the calling YAML
construct.

Examples:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/jinja-string01.yaml

The tag ``!j2-yaml:`` is similar to the ``!j2:`` tag, just that it loads the
Jinja-rendered string as YAML and embeds it in the calling YAML construct. This
provides a very flexible and convenient way of generating pieces of YAML
structures. One of use cases is defining complex YAML structures with much
simpler configuration, without any duplication.

Examples:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/jinja-yaml01.yaml

Another use case is controlling lists dynamically, like conditionally adding
list elements based on project configuration.

Examples:

    .. literalinclude:: /../../tests/yamlparser/job_fixtures/jinja-yaml02.yaml

"""

import abc
import importlib
import logging
import traceback
import sys
from pathlib import Path

import jinja2
import jinja2.meta
import yaml

from .errors import Context, JenkinsJobsException
from .loc_loader import LocList
from .position import Pos
from .formatter import CustomFormatter, enum_str_format_required_params

if sys.version_info >= (3, 8):
    from functools import cached_property
else:
    from .cached_property import cached_property

logger = logging.getLogger(__name__)


class BaseYamlObject(metaclass=abc.ABCMeta):
    @staticmethod
    def path_list_from_node(loader, node):
        if isinstance(node, yaml.ScalarNode):
            return LocList(
                [loader.construct_yaml_str(node)],
                value_pos=[loader.pos_from_node(node)],
            )
        elif isinstance(node, yaml.SequenceNode):
            return LocList(
                loader.construct_sequence(node),
                value_pos=[loader.pos_from_node(n) for n in node.value],
            )
        else:
            raise JenkinsJobsException(
                f"Expected either a sequence or scalar node, but found {node.id}",
                pos=loader.pos_from_node(node),
            )

    @classmethod
    def from_yaml(cls, loader, node):
        value = loader.construct_yaml_str(node)
        return cls(loader.jjb_config, loader, loader.pos_from_node(node), value)

    def __init__(self, jjb_config, loader, pos):
        self._search_path = jjb_config.yamlparser["include_path"].copy()
        if loader.source_dir:
            # Loaded from a file, find includes beside it too.
            self._search_path.append(loader.source_dir)
        self._filter_modules = jjb_config.yamlparser["filter_modules"].copy()
        self._loader = loader
        self._pos = pos
        allow_empty = jjb_config.yamlparser["allow_empty_variables"]
        self._formatter = CustomFormatter(allow_empty)

    @abc.abstractmethod
    def expand(self, expander, params):
        """Expand object and substitute template parameters"""
        pass

    def _find_file(self, rel_path, pos):
        search_path = self._search_path
        if "." not in search_path:
            search_path.append(".")
        dir_list = [Path(d).expanduser() for d in self._search_path]
        for dir in dir_list:
            candidate = dir.joinpath(rel_path)
            if candidate.is_file():
                logger.debug("Including file %r from path %r", str(rel_path), str(dir))
                return candidate
        dir_list_str = ",".join(str(d) for d in dir_list)
        raise JenkinsJobsException(
            f"File {rel_path} does not exist in any of include directories: {dir_list_str}",
            pos=pos,
        )

    def _expand_path_list(self, path_list, *args):
        for idx, path in enumerate(path_list):
            yield self._expand_path(path, path_list.value_pos[idx], *args)


class J2BaseYamlObject(BaseYamlObject):
    def __init__(self, jjb_config, loader, pos):
        super().__init__(jjb_config, loader, pos)
        self._filters = {}
        for module_name in self._filter_modules:
            module = importlib.import_module(module_name)
            self._filters.update(module.FILTERS)
        self._jinja2_env = jinja2.Environment(
            loader=jinja2.FileSystemLoader(self._search_path),
            undefined=jinja2.StrictUndefined,
        )
        self._jinja2_env.filters.update(self._filters)

    def _render_template(self, pos, template_text, template, params):
        try:
            return template.render(params)
        except jinja2.UndefinedError as x:
            # Jinja2 adds fake traceback entry with template line number.
            tb = traceback.extract_tb(x.__traceback__)
            line_ofs = tb[-1].lineno - 1  # traceback lineno starts with 1.
            lines = template_text.splitlines()
            start_ofs = pos.body.index(lines[0])
            # Examples for pre_pad: '!j2: \n<indent spaces>', '!j2: '.
            pre_pad = pos.body[:start_ofs]
            # Shift position to reflect template position inside yaml file:
            if "\n" in pre_pad:
                pos = pos.with_offset(line_ofs=1)
                column_ofs = 0
            else:
                column_ofs = start_ofs
            # Move position to error inside template:
            pos = pos.with_offset(line_ofs, column_ofs)
            pos = pos.with_contents_start()
            if len(template_text) > 40:
                text = template_text[:40] + "..."
            else:
                text = template_text
            context = Context(f"While formatting jinja2 template {text!r}", self._pos)
            raise JenkinsJobsException(str(x), pos=pos, ctx=[context])


class J2Template(J2BaseYamlObject):
    def __init__(self, jjb_config, loader, pos, template_text):
        super().__init__(jjb_config, loader, pos)
        self._template_text = template_text
        self._template = self._jinja2_env.from_string(template_text)

    def _params_from_referenced_templates(self, template_text):
        """
        Find recursively undeclared jinja2 variables from any
        (nested) included template(s)
        """
        required_params = set()
        ast = self._jinja2_env.parse(template_text)
        for rt in jinja2.meta.find_referenced_templates(ast):
            # recursive call to find params also from nested includes
            template_text = Path(self._find_file(rt, 0)).read_text()
            required_params.update(
                self._params_from_referenced_templates(template_text)
            )
        required_params.update(jinja2.meta.find_undeclared_variables(ast))
        return required_params

    @cached_property
    def required_params(self):
        return self._params_from_referenced_templates(self._template_text)

    def _render(self, params):
        return self._render_template(
            self._pos, self._template_text, self._template, params
        )


class J2String(J2Template):
    yaml_tag = "!j2:"

    def expand(self, expander, params):
        return self._render(params)


class J2Yaml(J2Template):
    yaml_tag = "!j2-yaml:"

    def expand(self, expander, params):
        text = self._render(params)
        data = self._loader.load(
            text, source_path="<expanded j2-yaml>", source_dir=self._loader.source_dir
        )
        try:
            return expander.expand(data, params)
        except JenkinsJobsException as x:
            raise x.with_context("In expanded !j2-yaml:", self._pos)


class IncludeJinja2(J2BaseYamlObject):
    yaml_tag = "!include-jinja2:"

    @classmethod
    def from_yaml(cls, loader, node):
        path_list = cls.path_list_from_node(loader, node)
        return cls(loader.jjb_config, loader, loader.pos_from_node(node), path_list)

    def __init__(self, jjb_config, loader, pos, path_list):
        super().__init__(jjb_config, loader, pos)
        self._path_list = path_list

    @property
    def required_params(self):
        return []

    def expand(self, expander, params):
        return "\n".join(self._expand_path_list(self._path_list, expander, params))

    def _expand_path(self, path_template, pos, expander, params):
        rel_path = self._formatter.format(path_template, **params)
        full_path = self._find_file(rel_path, pos)
        template_text = full_path.read_text()
        template = self._jinja2_env.from_string(template_text)
        pos = Pos.from_file(full_path, template_text)
        try:
            return self._render_template(pos, template_text, template, params)
        except JenkinsJobsException as x:
            raise x.with_context(f"In included file {str(full_path)!r}", pos=self._pos)


class IncludeBaseObject(BaseYamlObject):
    @classmethod
    def from_yaml(cls, loader, node):
        path_list = cls.path_list_from_node(loader, node)
        return cls(loader.jjb_config, loader, loader.pos_from_node(node), path_list)

    def __init__(self, jjb_config, loader, pos, path_list):
        super().__init__(jjb_config, loader, pos)
        self._path_list = path_list

    @property
    def required_params(self):
        for idx, path in enumerate(self._path_list):
            yield from enum_str_format_required_params(
                path, pos=self._path_list.value_pos[idx]
            )


class YamlInclude(IncludeBaseObject):
    yaml_tag = "!include:"

    def expand(self, expander, params):
        yaml_list = list(self._expand_path_list(self._path_list, expander, params))
        if len(yaml_list) == 1:
            return yaml_list[0]
        else:
            return "\n".join(yaml_list)

    def _expand_path(self, path_template, pos, expander, params):
        rel_path = self._formatter.format(path_template, **params)
        full_path = self._find_file(rel_path, pos)
        data = self._loader.load_path(full_path)
        try:
            return expander.expand(data, params)
        except JenkinsJobsException as x:
            raise x.with_context(f"In included file {str(full_path)!r}", pos=self._pos)


class IncludeRawBase(IncludeBaseObject):
    def expand(self, expander, params):
        return "\n".join(self._expand_path_list(self._path_list, params))


class IncludeRawExpand(IncludeRawBase):
    yaml_tag = "!include-raw-expand:"

    def _expand_path(self, rel_path_template, pos, params):
        rel_path = self._formatter.format(rel_path_template, **params)
        full_path = self._find_file(rel_path, pos)
        template = full_path.read_text()
        try:
            return self._formatter.format(template, **params)
        except JenkinsJobsException as x:
            raise x.with_context(f"In included file {str(full_path)!r}", pos=self._pos)


class IncludeRawVerbatim(IncludeRawBase):
    yaml_tag = "!include-raw-verbatim:"

    def _expand_path(self, rel_path_template, pos, params):
        rel_path = self._formatter.format(rel_path_template, **params)
        full_path = self._find_file(rel_path, pos)
        return full_path.read_text()


class YamlListJoin:
    yaml_tag = "!join:"

    @classmethod
    def from_yaml(cls, loader, node):
        value = loader.construct_sequence(node, deep=True)
        if len(value) != 2:
            raise JenkinsJobsException(
                "Join value should contain 2 elements: delimiter and string list,"
                f" but contains {len(value)} elements: {value!r}",
                pos=loader.pos_from_node(node),
            )
        delimiter, seq = value
        return delimiter.join(seq)
