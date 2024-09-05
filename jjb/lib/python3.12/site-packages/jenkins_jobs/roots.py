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

import logging
from collections import defaultdict

from .errors import Context, JenkinsJobsException
from .defaults import Defaults
from .job import Job, JobTemplate, JobGroup
from .view import View, ViewTemplate, ViewGroup
from .project import Project
from .macro import macro_adders

logger = logging.getLogger(__name__)


root_adders = {
    "defaults": Defaults.add,
    "job": Job.add,
    "job-template": JobTemplate.add,
    "job-group": JobGroup.add,
    "view": View.add,
    "view-template": ViewTemplate.add,
    "view-group": ViewGroup.add,
    "project": Project.add,
    **macro_adders,
}


class Roots:
    """Container for root YAML elements - jobs, views, templates, projects and macros"""

    def __init__(self, config):
        self._allow_duplicates = config.yamlparser["allow_duplicates"]
        self.defaults = {}
        self.jobs = {}
        self.job_templates = {}
        self.job_groups = {}
        self.views = {}
        self.view_templates = {}
        self.view_groups = {}
        self.projects = {}
        self.macros = defaultdict(dict)  # type -> name -> Macro

    def generate_jobs(self):
        expanded_jobs = []
        for job in self.jobs.values():
            expanded_jobs += job.top_level_generate_items()
        for project in self.projects.values():
            expanded_jobs += project.generate_jobs()
        return self._remove_duplicates(expanded_jobs, "job")

    def generate_views(self):
        expanded_views = []
        for view in self.views.values():
            expanded_views += view.top_level_generate_items()
        for project in self.projects.values():
            expanded_views += project.generate_views()
        return self._remove_duplicates(expanded_views, "view")

    def assign(self, container, id, value, element_type):
        if id in container:
            self._handle_dups(element_type, id, value.pos, container[id].pos)
        container[id] = value

    def _remove_duplicates(self, job_or_view_list, element_type):
        seen = {}
        unique_list = []
        # Last definition wins.
        for job_or_view in reversed(job_or_view_list):
            name = job_or_view.name
            if name in seen:
                origin = seen[name]
                self._handle_dups(
                    element_type,
                    name,
                    job_or_view.data.pos,
                    origin.data.pos,
                    # Skip job context, leave only project context.
                    job_or_view.context[:-1],
                    origin.context[:-1],
                )
            else:
                unique_list.append(job_or_view)
                seen[name] = job_or_view
        return unique_list[::-1]

    def _handle_dups(
        self, element_type, id, pos, origin_pos, ctx=None, origin_ctx=None
    ):
        message = f"Duplicate {element_type}: {id!r}"
        if self._allow_duplicates:
            logger.warning(message)
        else:
            logger.error(message)
            ctx = [*(ctx or []), Context(message, pos), *(origin_ctx or [])]
            raise JenkinsJobsException(
                f"Previous {element_type} definition", origin_pos, ctx
            )
