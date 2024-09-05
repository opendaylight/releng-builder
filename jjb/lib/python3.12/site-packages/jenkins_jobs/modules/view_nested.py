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
The view nested module handles creating Jenkins Nested views.

To create a nested view specify ``nested`` in the ``view-type`` attribute
to the :ref:`view_nested` definition.

:View Parameters:
    * **name** (`str`): The name of the view.
    * **view-type** (`str`): The type of view.
    * **description** (`str`): A description of the view. (default '')
    * **filter-executors** (`bool`): Show only executors that can
      execute the included views. (default false)
    * **filter-queue** (`bool`): Show only included jobs in builder
      queue. (default false)
    * **views** (`list`): The views to nest.
    * **default-view** (`str`): Name of the view to use as the default from the
      nested ones. (the first one by default)
    * **columns** (`list`): List of columns to be shown in view. (default empty
      list)

Example:

    .. literalinclude::
        /../../tests/views/fixtures/view_nested.yaml

"""

import xml.etree.ElementTree as XML
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers
from jenkins_jobs.root_base import JobViewData
from jenkins_jobs.xml_config import XmlViewGenerator

COLUMN_DICT = {
    "status": "hudson.views.StatusColumn",
    "weather": "hudson.views.WeatherColumn",
}


class Nested(jenkins_jobs.modules.base.Base):
    def root_xml(self, data):
        root = XML.Element("hudson.plugins.nested__view.NestedView")

        mapping = [
            ("name", "name", None),
            ("description", "description", ""),
            ("filter-executors", "filterExecutors", False),
            ("filter-queue", "filterQueue", False),
        ]
        helpers.convert_mapping_to_xml(root, data, mapping, fail_required=True)

        XML.SubElement(root, "properties", {"class": "hudson.model.View$PropertyList"})

        v_xml = XML.SubElement(root, "views")
        views = data.get("views", [])
        view_data_list = [JobViewData(v) for v in views]

        xml_view_generator = XmlViewGenerator(self.registry)
        xml_views = xml_view_generator.generateXML(view_data_list)

        for xml_job in xml_views:
            v_xml.append(xml_job.xml)

        d_xml = XML.SubElement(root, "defaultView")
        d_xml.text = data.get("default-view", views[0]["name"])

        c_xml = XML.SubElement(root, "columns")
        # there is a columns element in a columns element
        c_xml = XML.SubElement(c_xml, "columns")
        columns = data.get("columns", [])

        for column in columns:
            if column in COLUMN_DICT:
                XML.SubElement(c_xml, COLUMN_DICT[column])
            else:
                raise ValueError(
                    "Unsupported column %s is not one of: %s."
                    % (column, ", ".join(COLUMN_DICT.keys()))
                )

        return root
