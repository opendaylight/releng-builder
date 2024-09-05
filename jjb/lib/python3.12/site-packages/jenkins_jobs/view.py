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

from dataclasses import dataclass

from .errors import JenkinsJobsException
from .loc_loader import LocDict
from .expander import Expander
from .root_base import RootBase, NonTemplateRootMixin, TemplateRootMixin, Group
from .defaults import split_contents_params, view_contents_keys


@dataclass
class ViewBase(RootBase):
    view_type: str

    @classmethod
    def from_dict(cls, config, roots, data, pos):
        keep_descriptions = config.yamlparser["keep_descriptions"]
        d = data.copy()
        name = d.pop_required_loc_string("name")
        id = d.pop_loc_string("id", None)
        description = d.pop_loc_string("description", None)
        defaults = d.pop_loc_string("defaults", "global")
        view_type = d.pop_loc_string("view-type", "list")
        contents, params = split_contents_params(d, view_contents_keys)
        return cls(
            _defaults=roots.defaults,
            _expander=Expander(config),
            _keep_descriptions=keep_descriptions,
            _id=id,
            name=name,
            pos=pos,
            description=description,
            defaults_name=defaults,
            params=params,
            _contents=contents,
            view_type=view_type,
        )

    @property
    def contents(self):
        return LocDict.merge(
            {
                "name": self.name,
                "view-type": self.view_type,
            },
            super().contents,
        )


class View(ViewBase, NonTemplateRootMixin):
    @classmethod
    def add(cls, config, roots, data, pos):
        view = cls.from_dict(config, roots, data, pos)
        roots.assign(roots.views, view.id, view, "view")

    def __str__(self):
        return f"view {self.name!r}"


class ViewTemplate(ViewBase, TemplateRootMixin):
    @classmethod
    def add(cls, config, roots, data, pos):
        template = cls.from_dict(config, roots, data, pos)
        roots.assign(roots.view_templates, template.id, template, "view template")

    def __str__(self):
        return f"view template {self.name!r}"


@dataclass
class ViewGroup(Group):
    _views: dict
    _view_templates: dict

    @classmethod
    def add(cls, config, roots, data, pos):
        d = data.copy()
        name = d.pop_required_loc_string("name")
        try:
            view_specs = cls._specs_from_list(d.pop("views", None))
        except JenkinsJobsException as x:
            raise x.with_context(f"In view {name!r}", pos=pos)
        group = cls(
            name,
            pos,
            view_specs,
            d,
            roots.views,
            roots.view_templates,
        )
        roots.assign(roots.view_groups, group.name, group, "view group")

    def __str__(self):
        return f"view group {self.name!r}"

    @property
    def _root_dicts(self):
        return [self._views, self._view_templates]
