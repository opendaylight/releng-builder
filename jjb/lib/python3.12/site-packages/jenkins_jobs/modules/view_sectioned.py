# Copyright 2019 Openstack Foundation

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
The view sectioned module handles creating Jenkins Sectioned views.

To create a sectioned view specify ``sectioned`` in the ``view-type`` attribute
to the :ref:`view_sectioned` definition.

:View Parameters:
    * **name** (`str`): The name of the view.
    * **view-type** (`str`): The type of view.
    * **description** (`str`): A description of the view. (default '')
    * **filter-executors** (`bool`): Show only executors that can
      execute the included views. (default false)
    * **filter-queue** (`bool`): Show only included jobs in builder
      queue. (default false)
    * **sections** (`list`): The views to show in sections.

Example:

    .. literalinclude::
        /../../tests/views/fixtures/view_sectioned.yaml

"""

import xml.etree.ElementTree as XML
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers
from jenkins_jobs.modules import view_list


class Sectioned(jenkins_jobs.modules.base.Base):
    def root_xml(self, data):
        root = XML.Element("hudson.plugins.sectioned__view.SectionedView")

        mapping = [
            ("name", "name", None),
            ("description", "description", ""),
            ("filter-executors", "filterExecutors", False),
            ("filter-queue", "filterQueue", False),
        ]
        helpers.convert_mapping_to_xml(root, data, mapping, fail_required=True)

        XML.SubElement(root, "properties", {"class": "hudson.model.View$PropertyList"})

        s_xml = XML.SubElement(root, "sections")
        sections = data.get("sections", [])

        for section in sections:
            if "view-type" not in section:
                raise KeyError("This sectioned view is missing a view-type.", section)
            if section["view-type"] == "list":
                project = view_list.List(self.registry)
            elif section["view-type"] == "text":
                project = SectionedText(self.registry)
            else:
                raise ValueError(
                    "Nested view-type %s is not known. Supported types: list, text."
                    % section["view-type"]
                )
            xml_project = project.root_xml(section, sectioned=True)
            s_xml.append(xml_project)

        return root


class SectionedText(jenkins_jobs.modules.base.Base):
    def root_xml(self, data, sectioned=False):
        assert sectioned

        root = XML.Element("hudson.plugins.sectioned__view.TextSection")

        # these are in the XML and look like from view_list,
        # but the UI has no controls for them
        jn_xml = XML.SubElement(root, "jobNames")
        XML.SubElement(
            jn_xml, "comparator", {"class": "hudson.util.CaseInsensitiveComparator"}
        )
        XML.SubElement(root, "jobFilters")

        mapping = [
            ("name", "name", ""),
            ("width", "width", "FULL", ["FULL", "HALF", "THIRD", "TWO_THIRDS"]),
            ("alignment", "alignment", "CENTER", ["CENTER", "LEFT", "RIGHT"]),
            ("text", "text", None),
            ("style", "style", "NONE", ["NONE", "NOTE", "INFO", "WARNING", "TIP"]),
        ]
        helpers.convert_mapping_to_xml(root, data, mapping, fail_required=True)

        return root
