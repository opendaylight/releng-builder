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

from collections import namedtuple
from dataclasses import dataclass, field
from typing import List

from .constants import MAGIC_MANAGE_STRING
from .errors import Context, JenkinsJobsException
from .loc_loader import LocDict, LocString
from .position import Pos
from .formatter import enum_str_format_required_params, enum_str_format_param_defaults
from .expander import Expander, expand_parameters
from .defaults import Defaults
from .dimensions import enum_dimensions_params, is_point_included


@dataclass
class JobViewData:
    """Expanded job or view data, with added source context. Fed into xml generator"""

    data: LocDict
    context: List[Context] = field(default_factory=list)

    @property
    def name(self):
        return self.data["name"]

    def with_context(self, message, pos):
        return JobViewData(self.data, [Context(message, pos), *self.context])


@dataclass
class ElementBase:
    """Base class for YAML elements - job, view, template, or macro"""

    _defaults: dict
    params: dict

    @property
    def title(self):
        return str(self).capitalize()

    def _pick_defaults(self, name):
        try:
            defaults = self._defaults[name]
        except KeyError:
            if name == "global":
                return Defaults.empty()
            raise JenkinsJobsException(
                f"{self.title} wants defaults {name!r}, but it was never defined",
                pos=name.pos,
            )
        if name == "global":
            return defaults
        return defaults.merged_with_global(self._pick_defaults("global"))


@dataclass
class RootBase(ElementBase):
    """Base class for YAML root elements - job, view or template"""

    _expander: Expander
    _keep_descriptions: bool
    _id: str
    name: str
    pos: Pos
    description: str
    defaults_name: str
    _contents: dict

    @property
    def id(self):
        if self._id:
            return self._id
        else:
            return self.name

    @property
    def contents(self):
        contents = self._contents.copy()
        if self.description is not None:
            contents["description"] = self.description
        return contents

    def _expand_contents(self, contents, params):
        expanded_contents = self._expander.expand(contents, params)
        description = expanded_contents.get("description")
        if description is not None or not self._keep_descriptions:
            amended_description = (description or "") + MAGIC_MANAGE_STRING
            expanded_contents["description"] = amended_description
        return expanded_contents


class NonTemplateRootMixin:
    def top_level_generate_items(self):
        try:
            defaults = self._pick_defaults(self.defaults_name)
            item_params = LocDict.merge(
                defaults.params,
                self.params,
            )
            contents = LocDict.merge(
                defaults.contents,
                self.contents,
                pos=self.pos,
            )
            expanded_contents = self._expand_contents(contents, item_params)
            context = [Context(f"In {self}", self.pos)]
            yield JobViewData(expanded_contents, context)
        except JenkinsJobsException as x:
            raise x.with_context(f"In {self}", pos=self.pos)

    def generate_items(self, defaults_name, params):
        # Do not produce jobs/views from under project - they are produced when
        # processed directly from roots, by top_level_generate_items.
        return []


class TemplateRootMixin:
    def generate_items(self, defaults_name, params):
        try:
            defaults = self._pick_defaults(defaults_name or self.defaults_name)
            item_params = LocDict.merge(
                defaults.params,
                self.params,
                params,
                {"template-name": self.name},
            )
            if self._id:
                item_params["id"] = self._id
            contents = LocDict.merge(
                defaults.contents,
                self.contents,
                pos=self.pos,
            )
            axes = list(enum_str_format_required_params(self.name, self.name.pos))
            axes_defaults = dict(enum_str_format_param_defaults(self.name))
            for dim_params in enum_dimensions_params(axes, item_params, axes_defaults):
                instance_params = LocDict.merge(
                    item_params,
                    dim_params,
                )
                expanded_params = expand_parameters(self._expander, instance_params)
                if not is_point_included(
                    exclude_list=expanded_params.get("exclude"),
                    params=expanded_params,
                    key_pos=expanded_params.key_pos.get("exclude"),
                ):
                    continue
                expanded_contents = self._expand_contents(contents, expanded_params)
                context = [Context(f"In {self}", self.pos)]
                yield JobViewData(expanded_contents, context)
        except JenkinsJobsException as x:
            raise x.with_context(f"In {self}", pos=self.pos)


class GroupBase:
    Spec = namedtuple("Spec", "name params pos")

    def __repr__(self):
        return f"<{self}>"

    @classmethod
    def _specs_from_list(cls, spec_list=None):
        if spec_list is None:
            return []
        return [
            cls._spec_from_dict(item, spec_list.value_pos[idx])
            for idx, item in enumerate(spec_list)
        ]

    @classmethod
    def _spec_from_dict(cls, d, pos):
        if isinstance(d, (str, LocString)):
            return cls.Spec(d, params={}, pos=pos)
        if not isinstance(d, dict):
            raise JenkinsJobsException(
                "Job/view spec should name or dict,"
                f" but is {type(d)} ({d!r}). Missing indent?",
                pos=pos,
            )
        if len(d) != 1:
            raise JenkinsJobsException(
                "Job/view dict should be single-item,"
                f" but have keys {list(d.keys())}. Missing indent?",
                pos=d.pos,
            )
        name, params = next(iter(d.items()))
        if params is None:
            params = {}
        else:
            if not isinstance(params, dict):
                raise JenkinsJobsException(
                    f"Job/view {name!r} params type should be dict,"
                    f" but is {params!r}.",
                    pos=params.pos,
                )
        return cls.Spec(name, params, pos)

    def _generate_items(self, root_dicts, spec_list, defaults_name, params):
        try:
            for spec in spec_list:
                item = self._pick_spec_item(root_dicts, spec)
                item_params = LocDict.merge(
                    params,
                    self.params,
                    self._my_params,
                    spec.params,
                )
                for job_data in item.generate_items(defaults_name, item_params):
                    yield (
                        job_data.with_context("Defined here", spec.pos).with_context(
                            f"In {self}", self.pos
                        )
                    )
        except JenkinsJobsException as x:
            raise x.with_context(f"In {self}", self.pos)

    @property
    def _my_params(self):
        return {}

    def _pick_spec_item(self, root_dict_list, spec):
        for roots_dict in root_dict_list:
            try:
                return roots_dict[spec.name]
            except KeyError:
                pass
        raise JenkinsJobsException(
            f"Failed to find suitable job/view/template named '{spec.name}'",
            pos=spec.pos,
        )


@dataclass
class Group(GroupBase):
    name: str
    pos: Pos
    specs: list  # list[Spec]
    params: dict

    def generate_items(self, defaults_name, params):
        return self._generate_items(self._root_dicts, self.specs, defaults_name, params)
