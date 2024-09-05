# Copyright 2020 Openstack Foundation

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
The view delivery pipeline module handles creation of Delivery Pipeline views.
To create a delivery pipeline view specify ``delivery_pipeline`` in the
``view-type`` attribute to the :ref:`view_delivery_pipeline` definition.
Requires the Jenkins :jenkins-plugins:`Delivery Pipeline Plugin
<delivery-pipeline-plugin>`.

:View Parameters:
    * **name** (`str`): The name of the view.
    * **view-type** (`str`): The type of view.
    * **description** (`str`): A description of the view. (optional)
    * **filter-executors** (`bool`): Show only executors that can
      execute the included views. (default false)
    * **filter-queue** (`bool`): Show only included jobs in builder
      queue. (default false)
    * **components** (`list`):
        * **name** (`str`): Name of the pipeline, usually the name of the
          component or product.
        * **initial-job** (`str`): First job in the pipeline.
        * **final-job** (`str`): Final job to display in the pipeline view
          regardless of its downstream jobs. (default '')
        * **show-upstream** (`bool`): Whether to show upstream. (default false)
    * **regexps** (`list`):
        * **regexp** (`str`): Regular expression to find initial jobs.
        * **show-upstream** (`bool`): Whether to show upstream. (default false)
    * **aggregated-changes-grouping-pattern** (`str`): Group changelog by regex
      pattern. (default '')
    * **allow-abort** (`bool`): Allow cancelling a running job from the
      delivery pipeline view. (default false)
    * **allow-manual-triggers** (`bool`): Displays a button in the pipeline
      view if a task is manual (Build other projects (manual step)) from Build
      Pipeline Plugin. (default false)
    * **allow-pipeline-start** (`bool`): Allow starting a new pipeline run from
      the delivery pipeline view. (default false)
    * **allow-rebuild** (`bool`): Allow rerunning a task from the delivery
      pipeline view. (default false)
    * **link-relative** (`bool`): Use relative links for jobs in this pipeline
      view to allow for easier navigation. (default false)
    * **link-to-console-log** (`bool`): Changes behaviour of task link in
      delivery pipeline view to go directly to the console log. (default false)
    * **max-number-of-visible-pipelines** (`int`): Limits the number of
      pipelines shown in the view, regardless of how many pipelines are
      configured. A negative value will not enforce a limit.
    * **no-of-columns** (`int`): Number of columns used for showing pipelines.
      Possible values are 1 (default), 2 and 3.
    * **no-of-pipelines** (`int`): Number of pipelines instances shown for each
      pipeline. Possible values are numbers from 1 to 50 (default 3).
    * **paging-enabled** (`bool`): Enable pagination in normal view, to allow
      navigation to older pipeline runs which are not displayed on the first
      page. Not available in full screen view. (default false)
    * **show-absolute-date-time** (`bool`): Show dates and times as absolute
      values instead of as relative to the current time. (default false)
    * **show-aggregated-changes** (`bool`): Show an aggregated changelog
      between different stages. (default false)
    * **show-aggregated-pipeline** (`bool`): Show an aggregated view where each
      stage shows the latest version being executed. (default false)
    * **show-avatars** (`bool`): Show avatars pictures instead of names of the
      people involved in a pipeline instance. (default false)
    * **show-changes** (`bool`): Show SCM change log for the first job in the
      pipeline. (default false)
    * **show-description** (`bool`): Show a build description connected to a
      specific pipeline task. (default false)
    * **show-promotions** (`bool`): Show promotions from Promoted Builds
      Plugin. (default false)
    * **show-static-analysis-results** (`bool`): Show different analysis
      results from Analysis Collector Plugin. (default false)
    * **show-test-results** (`bool`): Show test results as pass/failed/skipped.
      (default false)
    * **show-total-build-time** (`bool`): Show total build time for a pipeline
      run. (default false)
    * **sorting** (`str`): How to sort the pipelines in the current view. Only
      applicable when multiple pipelines are configured in the same view.
      Possible values are 'none' (default), 'title' (sort by title),
      'failed_last_activity' (sort by failed pipelines, then by last activity),
      'last_activity' (sort by last activity).
    * **update-interval** (`int`): How often the pipeline view will be updated.
      To be specified in seconds. (default 2)

Minimal Example:

    .. literalinclude::
        /../../tests/views/fixtures/view_delivery_pipeline-minimal.yaml

Full Example:

    .. literalinclude::
        /../../tests/views/fixtures/view_delivery_pipeline-full.yaml
"""

import xml.etree.ElementTree as XML
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers


class DeliveryPipeline(jenkins_jobs.modules.base.Base):
    def root_xml(self, data):
        root = XML.Element(
            "se.diabol.jenkins.pipeline.DeliveryPipelineView",
            {"plugin": "delivery-pipeline-plugin"},
        )

        # Optional
        mapping_optional = [
            ("description", "description", None),
            ("filter-executors", "filterExecutors", False),
            ("filter-queue", "filterQueue", False),
        ]
        helpers.convert_mapping_to_xml(
            root, data, mapping_optional, fail_required=False
        )

        # Required - simple
        mapping = [
            (
                "aggregated-changes-grouping-pattern",
                "aggregatedChangesGroupingPattern",
                "",
            ),
            ("allow-abort", "allowAbort", False),
            ("allow-manual-triggers", "allowManualTriggers", False),
            ("allow-pipeline-start", "allowPipelineStart", False),
            ("allow-rebuild", "allowRebuild", False),
            ("link-relative", "linkRelative", False),
            ("link-to-console-log", "linkToConsoleLog", False),
            ("max-number-of-visible-pipelines", "maxNumberOfVisiblePipelines", -1),
            ("name", "name", None),
            ("no-of-columns", "noOfColumns", 1, [1, 2, 3]),
            ("no-of-pipelines", "noOfPipelines", 3, list(range(51))),
            ("paging-enabled", "pagingEnabled", False),
            ("show-absolute-date-time", "showAbsoluteDateTime", False),
            ("show-aggregated-changes", "showAggregatedChanges", False),
            ("show-aggregated-pipeline", "showAggregatedPipeline", False),
            ("show-avatars", "showAvatars", False),
            ("show-changes", "showChanges", False),
            ("show-description", "showDescription", False),
            ("show-promotions", "showPromotions", False),
            ("show-static-analysis-results", "showStaticAnalysisResults", False),
            ("show-test-results", "showTestResults", False),
            ("show-total-build-time", "showTotalBuildTime", False),
            ("update-interval", "updateInterval", 2),
        ]
        helpers.convert_mapping_to_xml(root, data, mapping, fail_required=True)

        # Required - complex
        sorting_val = data.get("sorting", "none")
        sorting_map = {
            "none": "None",
            "title": ("se.diabol.jenkins.pipeline.sort.NameComparator"),
            "failed_last_activity": (
                "se.diabol.jenkins.pipeline.sort.FailedJobComparator"
            ),
            "last_activity": (
                "se.diabol.jenkins.pipeline.sort.LatestActivityComparator"
            ),
        }
        sorting = XML.SubElement(root, "sorting")

        if sorting_val in sorting_map:
            sorting.text = sorting_map[sorting_val]
        else:
            sorting.text = sorting_map["none"]

        components = data.get("components", [])

        if len(components):
            component_specs = XML.SubElement(root, "componentSpecs")

            for c in components:
                component_spec = XML.SubElement(
                    component_specs,
                    "se.diabol.jenkins.pipeline.DeliveryPipelineView_-ComponentSpec",
                )

                name = XML.SubElement(component_spec, "name")
                name.text = c.get("name", "")

                first_job = XML.SubElement(component_spec, "firstJob")
                first_job.text = c.get("initial-job", "")

                last_job = XML.SubElement(component_spec, "lastJob")
                last_job.text = c.get("final-job", "")

                show_upstream = XML.SubElement(component_spec, "showUpstream")
                show_upstream.text = c.get("show-upstream", "false")

        regexps = data.get("regexps", [])

        if len(regexps):
            regexp_first_jobs = XML.SubElement(root, "regexpFirstJobs")

            for r in regexps:
                regexp_first_job = XML.SubElement(
                    regexp_first_jobs,
                    "se.diabol.jenkins.pipeline.DeliveryPipelineView_-RegExpSpec",
                )

                regexp = XML.SubElement(regexp_first_job, "regexp")
                regexp.text = r.get("regexp", "")

                show_upstream = XML.SubElement(regexp_first_job, "showUpstream")
                show_upstream.text = r.get("show-upstream", "false")

        return root
