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
from .expander import Expander
from .root_base import RootBase, NonTemplateRootMixin, TemplateRootMixin, Group
from .defaults import split_contents_params, job_contents_keys


@dataclass
class JobBase(RootBase):
    project_type: str
    folder: str

    @classmethod
    def from_dict(cls, config, roots, data, pos):
        keep_descriptions = config.yamlparser["keep_descriptions"]
        d = data.copy()
        name = d.pop_required_loc_string("name")
        id = d.pop_loc_string("id", None)
        description = d.pop_loc_string("description", None)
        defaults = d.pop_loc_string("defaults", "global")
        project_type = d.pop_loc_string("project-type", None)
        folder = d.pop_loc_string("folder", None)
        contents, params = split_contents_params(d, job_contents_keys)
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
            project_type=project_type,
            folder=folder,
        )

    @property
    def contents(self):
        contents = super().contents
        contents["name"] = self.name
        if self.project_type:
            contents["project-type"] = self.project_type
        if self.folder:
            contents["folder"] = self.folder
        return contents

    def _expand_contents(self, contents, params):
        expanded_contents = super()._expand_contents(contents, params)
        try:
            folder = expanded_contents["folder"]
        except KeyError:
            pass
        else:
            name = expanded_contents["name"]
            expanded_contents["name"] = f"{folder}/{name}"
        return expanded_contents


class Job(JobBase, NonTemplateRootMixin):
    @classmethod
    def add(cls, config, roots, data, pos):
        job = cls.from_dict(config, roots, data, pos)
        roots.assign(roots.jobs, job.id, job, "job")

    def __str__(self):
        return f"job {self.name!r}"


class JobTemplate(JobBase, TemplateRootMixin):
    @classmethod
    def add(cls, config, roots, data, pos):
        template = cls.from_dict(config, roots, data, pos)
        roots.assign(roots.job_templates, template.id, template, "job template")

    def __str__(self):
        return f"job template {self.name!r}"


@dataclass
class JobGroup(Group):
    _jobs: dict
    _job_templates: dict

    @classmethod
    def add(cls, config, roots, data, pos):
        d = data.copy()
        name = d.pop_required_loc_string("name")
        try:
            job_specs = cls._specs_from_list(d.pop("jobs", None))
        except JenkinsJobsException as x:
            raise x.with_context(f"In job {name!r}", pos=pos)
        group = cls(
            name,
            pos,
            job_specs,
            d,
            roots.jobs,
            roots.job_templates,
        )
        roots.assign(roots.job_groups, group.name, group, "job group")

    def __str__(self):
        return f"job group {self.name!r}"

    @property
    def _root_dicts(self):
        return [self._jobs, self._job_templates]
