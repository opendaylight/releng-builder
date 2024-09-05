# -*- coding: utf-8 -*-
# Copyright (C) 2021 The Linux Foundation
#
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


"""
The Github Organization project module handles creating Jenkins Github
Organization jobs, which are made up of multibranch pipelines for all
repositories containing the specified Jenkinsfile(s).
You may specify ``githuborg`` in the ``project-type`` attribute of
the :ref:`Job` definition.

Plugins required:

* :jenkins-plugins:`GitHub Branch Source Plugin <github-branch-source>`

:Job Parameters:

    * **github-org** (`dict`): Refer to
      :func:`github_org <github_org>` for documentation.

    * **periodic-folder-trigger** (`str`): How often to scan for new branches
      or pull/change requests. Valid values: 1m, 2m, 5m, 10m, 15m, 20m, 25m,
      30m, 1h, 2h, 4h, 8h, 12h, 1d, 2d, 1w, 2w, 4w. (default none)
    * **prune-dead-branches** (`bool`): If dead branches upon check should
      result in their job being dropped. (default true)
    * **number-to-keep** (`int`): How many builds should be kept.
      (default '-1, all')
    * **days-to-keep** (`int`): For how many days should a build be kept.
      (default '-1, forever')
    * **script-path** (`str`): Path to Jenkinsfile, relative to workspace.
      (default 'Jenkinsfile')

Job examples:

.. literalinclude:: /../../tests/githuborg/fixtures/minimal.yaml

.. literalinclude:: /../../tests/githuborg/fixtures/githuborg-job-full.yaml

"""
import collections
import logging
import xml.etree.ElementTree as XML
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers
import jenkins_jobs.modules.project_multibranch as multibranch

from jenkins_jobs.modules.scm import git_extensions
from jenkins_jobs.errors import InvalidAttributeError

logger = logging.getLogger(str(__name__))


class GithubOrganization(jenkins_jobs.modules.base.Base):
    sequence = 0
    jenkins_class = "jenkins.branch.OrganizationFolder"

    def root_xml(self, data):
        xml_parent = XML.Element(self.jenkins_class)
        xml_parent.attrib["plugin"] = "branch-api"
        XML.SubElement(xml_parent, "properties")

        ################
        # Folder Views #
        ################

        folderViews = XML.SubElement(
            xml_parent,
            "folderViews",
            {"class": "jenkins.branch.OrganizationFolderViewHolder"},
        )

        XML.SubElement(folderViews, "owner", {"reference": "../.."})

        ##################
        # Health Metrics #
        ##################

        hm = XML.SubElement(xml_parent, "healthMetrics")
        hm_path = "com.cloudbees.hudson.plugins.folder.health" ".WorstChildHealthMetric"
        hm_plugin = XML.SubElement(hm, hm_path, {"plugin": "cloudbees-folder"})
        XML.SubElement(hm_plugin, "nonRecursive").text = "false"

        ########
        # Icon #
        ########

        icon = XML.SubElement(
            xml_parent, "icon", {"class": "jenkins.branch.MetadataActionFolderIcon"}
        )
        XML.SubElement(
            icon, "owner", {"class": self.jenkins_class, "reference": "../.."}
        )

        ########################
        # Orphan Item Strategy #
        ########################

        ois_default_strategy = (
            "com.cloudbees.hudson.plugins."
            "folder.computed.DefaultOrphanedItemStrategy"
        )
        ois = XML.SubElement(
            xml_parent,
            "orphanedItemStrategy",
            {"class": ois_default_strategy, "plugin": "cloudbees-folder"},
        )

        ois_mapping = [
            ("prune-dead-branches", "pruneDeadBranches", True, [True, False]),
            ("days-to-keep", "daysToKeep", -1),
            ("number-to-keep", "numToKeep", -1),
        ]
        helpers.convert_mapping_to_xml(ois, data, ois_mapping)

        ###########################
        # Periodic Folder Trigger #
        ###########################

        triggers = XML.SubElement(xml_parent, "triggers")

        # Valid options for the periodic trigger interval.
        pft_map = collections.OrderedDict(
            [
                ("1m", ("* * * * *", "60000")),
                ("2m", ("*/2 * * * *", "120000")),
                ("5m", ("*/5 * * * *", "300000")),
                ("10m", ("H/6 * * * *", "600000")),
                ("15m", ("H/6 * * * *", "900000")),
                ("20m", ("H/3 * * * *", "1200000")),
                ("25m", ("H/3 * * * *", "1500000")),
                ("30m", ("H/2 * * * *", "1800000")),
                ("1h", ("H * * * *", "3600000")),
                ("2h", ("H * * * *", "7200000")),
                ("4h", ("H * * * *", "14400000")),
                ("8h", ("H * * * *", "28800000")),
                ("12h", ("H H * * *", "43200000")),
                ("1d", ("H H * * *", "86400000")),
                ("2d", ("H H * * *", "172800000")),
                ("1w", ("H H * * *", "604800000")),
                ("2w", ("H H * * *", "1209600000")),
                ("4w", ("H H * * *", "2419200000")),
            ]
        )

        pft_val = data.get("periodic-folder-trigger")
        if pft_val:
            if not pft_map.get(pft_val):
                raise InvalidAttributeError(
                    "periodic-folder-trigger", pft_val, pft_map.keys()
                )

            pft_path = (
                "com.cloudbees.hudson.plugins.folder.computed." "PeriodicFolderTrigger"
            )
            pft = XML.SubElement(triggers, pft_path, {"plugin": "cloudbees-folder"})
            XML.SubElement(pft, "spec").text = pft_map[pft_val][0]
            XML.SubElement(pft, "interval").text = pft_map[pft_val][1]

        ##############
        # Navigators #
        ##############

        navigators = XML.SubElement(xml_parent, "navigators")
        navigators_plugin = XML.SubElement(
            navigators,
            "org.jenkinsci.plugins.github__branch__source.GitHubSCMNavigator",
            {"plugin": "github-branch-source"},
        )
        github_org(navigators_plugin, data.get("github-org"))

        ###########
        # Factory #
        ###########

        fopts_map = [("script-path", "scriptPath", "Jenkinsfile")]

        project_factories = XML.SubElement(xml_parent, "projectFactories")
        factory = XML.SubElement(
            project_factories,
            "org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProjectFactory",
            {"plugin": "workflow-multibranch"},
        )
        helpers.convert_mapping_to_xml(factory, data, fopts_map, fail_required=False)

        ####################
        # Build Strategies #
        ####################

        if data.get("github-org").get("build-strategies", None):
            multibranch.build_strategies(xml_parent, data.get("github-org"))

        return xml_parent


def github_org(xml_parent, data):
    r"""Configure GitHub Organization and SCM settings.

    :arg str repo-owner: Specify the name of the GitHub Organization or
        GitHub User Account. (required)
    :arg str api-uri: The GitHub API uri for hosted / on-site GitHub. Must
        first be configured in Global Configuration. (default GitHub)
    :arg str branch-discovery: Discovers branches on the repository.
        Valid options: no-pr, only-pr, all, false. (default 'no-pr')
    :arg str repo-name-regex: Regular expression used to match repository names
        within the organization. (optional)
        Requires the :jenkins-plugins:`SCM API plugin <scm-api>`.
    :arg list build-strategies: Provides control over whether to build a branch
        (or branch like things such as change requests and tags) whenever it is
        discovered initially or a change from the previous revision has been
        detected. (optional)
        Refer to :func:`~build_strategies <project_multibranch.build_strategies>`.
    :arg str credentials-id: Credentials used to scan branches and pull
        requests, check out sources and mark commit statuses. (optional)
    :arg str discover-pr-forks-strategy: Fork strategy. Valid options:
        merge-current, current, both, false. (default 'merge-current')
    :arg str discover-pr-forks-trust: Discovers pull requests where the origin
        repository is a fork of the target repository.
        Valid options: contributors, everyone, permission or nobody.
        (default 'contributors')
    :arg str discover-pr-origin: Discovers pull requests where the origin
        repository is the same as the target repository.
        Valid options: merge-current, current, both, false.  (default 'merge-current')
    :arg bool discover-tags: Discovers tags on the repository.
        (default false)
    :arg list head-pr-filter-behaviors: Definition of Filter Branch PR behaviors.
        Requires the :jenkins-plugins:`SCM Filter Branch PR Plugin
        <scm-filter-branch-pr>`. Refer to
        :func:`~add_filter_branch_pr_behaviors <project_multibranch.add_filter_branch_pr_behaviors>`.
    :arg dict notification-context: Change the default GitHub check notification
        context from "continuous-integration/jenkins/SUFFIX" to a custom label / suffix.
        (set a label and suffix to true or false, optional)
        Requires the :jenkins-plugins:`Github Custom Notification Context SCM
        Behaviour <github-scm-trait-notification-context>`.
        Refer to :func:`~add_notification_context_trait <project_multibranch.add_notification_context_trait>`.
    :arg dict property-strategies: Provides control over how to build a branch
        (like to disable SCM triggering or to override the pipeline durability)
        (optional)
        Refer to :func:`~property_strategies <project_multibranch.property_strategies>`.
    :arg bool exclude-archived-repositories: Whether archived repositories are
        excluded when scanning an organization. (default: false) (optional)
    :arg bool ssh-checkout: Checkout over SSH.

        * **credentials** ('str'): Credentials to use for
            checkout of the repo over ssh.

    :extensions:

        * **clean** (`dict`)
            * **after** (`dict`) - Clean the workspace after checkout
                * **remove-stale-nested-repos** (`bool`) - Deletes untracked
                  submodules and any other subdirectories which contain .git directories
                  (default false)
            * **before** (`dict`) - Clean the workspace before checkout
                * **remove-stale-nested-repos** (`bool`) - Deletes untracked
                  submodules and any other subdirectories which contain .git directories
                  (default false)
        * **depth** (`int`) - Set shallow clone depth (default 1)
        * **disable-pr-notifications** (`bool`) - Disable default github status
            notifications on pull requests (default false) (Requires the
            :jenkins-plugins:`GitHub Branch Source Plugin
            <disable-github-multibranch-status>`.)
        * **do-not-fetch-tags** (`bool`) - Perform a clone without tags
            (default false)
        * **lfs-pull** (`bool`) - Call git lfs pull after checkout
            (default false)
        * **prune** (`bool`) - Prune remote branches (default false)
        * **refspecs** (`list(str)`): Which refspecs to fetch.
        * **shallow-clone** (`bool`) - Perform shallow clone (default false)
        * **sparse-checkout** (dict)
            * **paths** (list) - List of paths to sparse checkout. (optional)
        * **submodule** (`dict`)
            * **disable** (`bool`) - By disabling support for submodules you
              can still keep using basic git plugin functionality and just have
              Jenkins to ignore submodules completely as if they didn't exist.
            * **recursive** (`bool`) - Retrieve all submodules recursively
              (uses '--recursive' option which requires git>=1.6.5)
            * **tracking** (`bool`) - Retrieve the tip of the configured
              branch in .gitmodules (Uses '\-\-remote' option which requires
              git>=1.8.2)
            * **parent-credentials** (`bool`) - Use credentials from default
              remote of parent repository (default false).
            * **reference-repo** (`str`) - Path of the reference repo to use
              during clone (optional)
            * **timeout** (`int`) - Specify a timeout (in minutes) for
              submodules operations (default 10).
        * **timeout** (`str`) - Timeout for git commands in minutes (optional)
        * **use-author** (`bool`): Use author rather than committer in Jenkin's
            build changeset (default false)
        * **wipe-workspace** (`bool`) - Wipe out workspace before build
            (default true)

    Job examples:

    .. literalinclude:: /../../tests/githuborg/fixtures/minimal.yaml

    .. literalinclude:: /../../tests/githuborg/fixtures/github-org-full.yaml

    """
    github_path = "org.jenkinsci.plugins.github_branch_source"
    github_path_dscore = "org.jenkinsci.plugins.github__branch__source"

    mapping = [("repo-owner", "repoOwner", None)]
    helpers.convert_mapping_to_xml(xml_parent, data, mapping, fail_required=True)

    mapping_optional = [
        ("api-uri", "apiUri", None),
        ("credentials-id", "credentialsId", None),
    ]
    helpers.convert_mapping_to_xml(
        xml_parent, data, mapping_optional, fail_required=False
    )

    traits = XML.SubElement(xml_parent, "traits")

    # no-pr value is assumed if branch-discovery not mentioned.
    if data.get("branch-discovery", "no-pr"):
        bd = XML.SubElement(
            traits, "".join([github_path_dscore, ".BranchDiscoveryTrait"])
        )
        bd_strategy = {"no-pr": "1", "only-pr": "2", "all": "3"}
        bd_mapping = [("branch-discovery", "strategyId", "no-pr", bd_strategy)]
        helpers.convert_mapping_to_xml(bd, data, bd_mapping, fail_required=True)

    if data.get("ssh-checkout", None):
        cossh = XML.SubElement(
            traits, "".join([github_path_dscore, ".SSHCheckoutTrait"])
        )
        if not isinstance(data.get("ssh-checkout"), bool):
            cossh_credentials = [("credentials", "credentialsId", "")]
            helpers.convert_mapping_to_xml(
                cossh, data.get("ssh-checkout"), cossh_credentials, fail_required=True
            )

    if data.get("discover-tags", False):
        XML.SubElement(traits, "".join([github_path_dscore, ".TagDiscoveryTrait"]))

    if data.get("discover-pr-forks-strategy", "merged-current"):
        dprf = XML.SubElement(
            traits, "".join([github_path_dscore, ".ForkPullRequestDiscoveryTrait"])
        )
        dprf_strategy = {"merge-current": "1", "current": "2", "both": "3"}
        dprf_mapping = [
            ("discover-pr-forks-strategy", "strategyId", "merge-current", dprf_strategy)
        ]
        helpers.convert_mapping_to_xml(dprf, data, dprf_mapping, fail_required=True)

        trust = data.get("discover-pr-forks-trust", "contributors")
        trust_map = {
            "contributors": "".join(
                [github_path, ".ForkPullRequestDiscoveryTrait$TrustContributors"]
            ),
            "everyone": "".join(
                [github_path, ".ForkPullRequestDiscoveryTrait$TrustEveryone"]
            ),
            "permission": "".join(
                [github_path, ".ForkPullRequestDiscoveryTrait$TrustPermission"]
            ),
            "nobody": "".join(
                [github_path, ".ForkPullRequestDiscoveryTrait$TrustNobody"]
            ),
        }
        if trust not in trust_map:
            raise InvalidAttributeError(
                "discover-pr-forks-trust", trust, trust_map.keys()
            )
        XML.SubElement(dprf, "trust").attrib["class"] = trust_map[trust]

    dpro_strategy = data.get("discover-pr-origin", "merge-current")
    if dpro_strategy:
        dpro = XML.SubElement(
            traits, "".join([github_path_dscore, ".OriginPullRequestDiscoveryTrait"])
        )
        dpro_strategy_map = {"merge-current": "1", "current": "2", "both": "3"}
        if dpro_strategy not in dpro_strategy_map:
            raise InvalidAttributeError(
                "discover-pr-origin", dpro_strategy, dpro_strategy_map.keys()
            )
        dpro_mapping = [
            ("discover-pr-origin", "strategyId", "merge-current", dpro_strategy_map)
        ]
        helpers.convert_mapping_to_xml(dpro, data, dpro_mapping, fail_required=True)

    if data.get("head-filter-regex", None):
        rshf = XML.SubElement(traits, "jenkins.scm.impl.trait.RegexSCMHeadFilterTrait")
        XML.SubElement(rshf, "regex").text = data.get("head-filter-regex")

    if data.get("repo-name-regex", None):
        rssf = XML.SubElement(
            traits,
            "jenkins.scm.impl.trait.RegexSCMSourceFilterTrait",
            {"plugin": "scm-api"},
        )
        XML.SubElement(rssf, "regex").text = data.get("repo-name-regex")

    if data.get("head-pr-filter-behaviors", None):
        multibranch.add_filter_branch_pr_behaviors(
            traits, data.get("head-pr-filter-behaviors")
        )

    if data.get("property-strategies", None):
        multibranch.property_strategies(xml_parent, data)

    multibranch.add_notification_context_trait(traits, data)

    # handle the default git extensions like:
    # - clean
    # - shallow-clone
    # - timeout
    # - do-not-fetch-tags
    # - submodule
    # - prune
    # - wipe-workspace
    # - use-author
    # - lfs-pull
    git_extensions(traits, data)

    if data.get("refspecs"):
        refspec_trait = XML.SubElement(
            traits,
            "jenkins.plugins.git.traits.RefSpecsSCMSourceTrait",
            {"plugin": "git"},
        )
        templates = XML.SubElement(refspec_trait, "templates")
        refspecs = data.get("refspecs")
        for refspec in refspecs:
            e = XML.SubElement(
                templates,
                (
                    "jenkins.plugins.git.traits"
                    ".RefSpecsSCMSourceTrait_-RefSpecTemplate"
                ),
            )
            XML.SubElement(e, "value").text = refspec

    # github-only extensions
    disable_github_status_path_dscore = (
        "com.adobe.jenkins.disable__github__multibranch__status"
    )
    if data.get("disable-pr-notifications", False):
        XML.SubElement(
            traits,
            "".join([disable_github_status_path_dscore, ".DisableStatusUpdateTrait"]),
            {"plugin": "disable-github-multibranch-status"},
        )

    if data.get("exclude-archived-repositories", False):
        XML.SubElement(
            traits,
            "".join([github_path_dscore, ".ExcludeArchivedRepositoriesTrait"]),
        )
