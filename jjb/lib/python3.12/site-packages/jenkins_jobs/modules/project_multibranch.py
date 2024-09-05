# -*- coding: utf-8 -*-
# Copyright (C) 2015 Joost van der Griendt <joostvdg@gmail.com>
# Copyright (C) 2018 Sorin Sbarnea <ssbarnea@users.noreply.github.com>
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
The Multibranch Pipeline project module handles creating Jenkins workflow
projects.
You may specify ``multibranch`` in the ``project-type`` attribute of
the :ref:`Job` definition.

Multibranch Pipeline implementantion in JJB is marked as **experimental**
which means that there is no guarantee that its behavior (or configuration)
will not change, even between minor releases.

Plugins required:

* :jenkins-plugins:`Workflow Plugin <workflow-aggregator>`.
* :jenkins-plugins:`Pipeline Multibranch Defaults Plugin
  <pipeline-multibranch-defaults>` (optional)
* :jenkins-plugins:`Basic Branch Build Strategies Plugin
  <basic-branch-build-strategies>` (optional)

:Job Parameters:

    * **scm** (`list`): The SCM definition.

        * **bitbucket** (`dict`): Refer to
          :func:`~bitbucket_scm <bitbucket_scm>` for documentation.

        * **gerrit** (`dict`): Refer to
          :func:`~gerrit_scm <gerrit_scm>` for documentation.

        * **git** (`dict`): Refer to
          :func:`~git_scm <git_scm>` for documentation.

        * **github** (`dict`): Refer to
          :func:`~github_scm <github_scm>` for documentation.

    * **periodic-folder-trigger** (`str`): How often to scan for new branches
      or pull/change requests. Valid values: 1m, 2m, 5m, 10m, 15m, 20m, 25m,
      30m, 1h, 2h, 4h, 8h, 12h, 1d, 2d, 1w, 2w, 4w. (default none)
    * **prune-dead-branches** (`bool`): If dead branches upon check should
      result in their job being dropped. (default true)
    * **number-to-keep** (`int`): How many builds should be kept.
      (default '-1, all')
    * **days-to-keep** (`int`): For how many days should a build be kept.
      (default '-1, forever')
    * **abort-builds** (`bool`): Abort all pending or ongoing builds for removed
      SCM heads (i.e. deleted branches). (default false)
    * **script-path** (`str`): Path to Jenkinsfile, relative to workspace.
      (default 'Jenkinsfile')
    * **script-id** (`str`): Script id from the global Jenkins script store
      provided by the config-file provider plugin. Mutually exclusive with
      **script-path** option.
    * **sandbox** (`bool`): This option is strongly recommended if the
      Jenkinsfile is using load to evaluate a groovy source file from an
      SCM repository. Usable only with **script-id** option. (default 'false')

Job examples:

.. literalinclude:: /../../tests/multibranch/fixtures/multibranch_defaults_id_mode.yaml

.. literalinclude:: /../../tests/multibranch/fixtures/multibranch_defaults_path_mode.yaml

.. literalinclude:: /../../tests/multibranch/fixtures/multi_scm_full.yaml

"""
import collections
import logging
import xml.etree.ElementTree as XML
import jenkins_jobs.modules.base
import jenkins_jobs.modules.helpers as helpers
import six

from jenkins_jobs.modules.scm import git_extensions
from jenkins_jobs.errors import InvalidAttributeError, MissingAttributeError
from jenkins_jobs.errors import Context, JenkinsJobsException
from jenkins_jobs.xml_config import remove_ignorable_whitespace

logger = logging.getLogger(str(__name__))


class WorkflowMultiBranch(jenkins_jobs.modules.base.Base):
    sequence = 0
    multibranch_path = "org.jenkinsci.plugins.workflow.multibranch"
    multibranch_defaults_path = "org.jenkinsci.pipeline.workflow.multibranch"
    jenkins_class = "".join([multibranch_path, ".WorkflowMultiBranchProject"])
    jenkins_factory = {
        "script_path": {
            "class": "".join([multibranch_path, ".WorkflowBranchProjectFactory"])
        },
        "script_id": {
            "class": "".join(
                [
                    multibranch_defaults_path,
                    ".defaults.PipelineBranchDefaultsProjectFactory",
                ]
            ),
            "plugin": "pipeline-multibranch-defaults",
        },
    }

    @staticmethod
    def _factory_opts_check(data):

        sandbox = data.get("sandbox", None)
        script_id = data.get("script-id", None)
        script_path = data.get("script-path", None)

        if script_id and script_path:
            error_msg = "script-id and script-path are mutually exclusive options"
            raise JenkinsJobsException(error_msg)
        elif not script_id and sandbox:
            error_msg = (
                "Sandbox mode is applicable only for multibranch with defaults"
                "project type used with script-id option"
            )
            raise JenkinsJobsException(error_msg)

    def root_xml(self, data):
        xml_parent = XML.Element(self.jenkins_class)
        xml_parent.attrib["plugin"] = "workflow-multibranch"
        XML.SubElement(xml_parent, "properties")

        #########
        # Views #
        #########

        views = XML.SubElement(xml_parent, "views")
        all_view = XML.SubElement(views, "hudson.model.AllView")
        all_view_mapping = [
            ("", "name", "All"),
            ("", "filterExecutors", False),
            ("", "filterQueue", False),
        ]
        helpers.convert_mapping_to_xml(
            all_view, {}, all_view_mapping, fail_required=True
        )

        XML.SubElement(
            all_view, "properties", {"class": "hudson.model.View$PropertyList"}
        )

        XML.SubElement(
            all_view, "owner", {"class": self.jenkins_class, "reference": "../../.."}
        )

        XML.SubElement(
            xml_parent, "viewsTabBar", {"class": "hudson.views.DefaultViewsTabBar"}
        )

        ################
        # Folder Views #
        ################

        folderViews = XML.SubElement(
            xml_parent,
            "folderViews",
            {
                "class": "jenkins.branch.MultiBranchProjectViewHolder",
                "plugin": "branch-api",
            },
        )

        XML.SubElement(
            folderViews, "owner", {"class": self.jenkins_class, "reference": "../.."}
        )

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
            xml_parent,
            "icon",
            {
                "class": "jenkins.branch.MetadataActionFolderIcon",
                "plugin": "branch-api",
            },
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
            ("abort-builds", "abortBuilds", False, [True, False]),
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

        ###########
        # Sources #
        ###########

        sources = XML.SubElement(
            xml_parent,
            "sources",
            {
                "class": "jenkins.branch.MultiBranchProject$BranchSourceList",
                "plugin": "branch-api",
            },
        )
        sources_data = XML.SubElement(sources, "data")
        XML.SubElement(
            sources, "owner", {"class": self.jenkins_class, "reference": "../.."}
        )

        valid_scm = ["bitbucket", "gerrit", "git", "github"]
        for scm_data in data.get("scm", None):
            for scm in scm_data:
                bs = XML.SubElement(sources_data, "jenkins.branch.BranchSource")

                if scm == "bitbucket":
                    bitbucket_scm(bs, scm_data[scm])

                elif scm == "gerrit":
                    gerrit_scm(bs, scm_data[scm])

                elif scm == "git":
                    git_scm(bs, scm_data[scm])

                elif scm == "github":
                    github_scm(bs, scm_data[scm])

                else:
                    raise InvalidAttributeError("scm", scm_data, valid_scm)

        ###########
        # Factory #
        ###########

        self._factory_opts_check(data)

        if data.get("script-id"):
            mode = "script_id"
            fopts_map = (
                ("script-id", "scriptId", None),
                ("sandbox", "useSandbox", None),
            )
        else:
            mode = "script_path"
            fopts_map = (("script-path", "scriptPath", "Jenkinsfile"),)

        factory = XML.SubElement(xml_parent, "factory", self.jenkins_factory[mode])
        XML.SubElement(
            factory, "owner", {"class": self.jenkins_class, "reference": "../.."}
        )

        # multibranch default

        helpers.convert_mapping_to_xml(factory, data, fopts_map, fail_required=False)

        return xml_parent


class WorkflowMultiBranchDefaults(WorkflowMultiBranch):
    multibranch_path = "org.jenkinsci.plugins.workflow.multibranch"
    multibranch_defaults_path = "org.jenkinsci.plugins.pipeline.multibranch"
    jenkins_class = "".join(
        [multibranch_defaults_path, ".defaults.PipelineMultiBranchDefaultsProject"]
    )
    jenkins_factory = {
        "script_path": {
            "class": "".join([multibranch_path, ".WorkflowBranchProjectFactory"]),
            "plugin": "workflow-multibranch",
        },
        "script_id": {
            "class": "".join(
                [
                    multibranch_defaults_path,
                    ".defaults.PipelineBranchDefaultsProjectFactory",
                ]
            )
        },
    }


def bitbucket_scm(xml_parent, data):
    r"""Configure BitBucket scm

    Requires the :jenkins-plugins:`Bitbucket Branch Source Plugin
    <cloudbees-bitbucket-branch-source>`.

    :arg str credentials-id: The credential to use to scan BitBucket.
        (required)
    :arg str repo-owner: Specify the name of the Bitbucket Team or Bitbucket
        User Account. (required)
    :arg str repo: The BitBucket repo. (required)

    :arg bool discover-tags: Discovers tags on the repository.
        (default false)
    :arg bool lfs: Git LFS pull after checkout.
        (default false)
    :arg str server-url: The address of the bitbucket server. (optional)
    :arg str head-filter-regex: A regular expression for filtering
        discovered source branches. Requires the :jenkins-plugins:`SCM API
        Plugin <scm-api>`.
    :arg list head-pr-filter-behaviors: Definition of Filter Branch PR behaviors.
        Requires the :jenkins-plugins:`SCM Filter Branch PR Plugin
        <scm-filter-branch-pr>`.
        Refer to :func:`~add_filter_branch_pr_behaviors <add_filter_branch_pr_behaviors>`.
    :arg str discover-branch: Discovers branches on the repository.
        Valid options: ex-pr, only-pr, all.
        Value is not specified by default.
    :arg str discover-pr-origin: Discovers pull requests where the origin
        repository is the same as the target repository.
        Valid options: mergeOnly, headOnly, mergeAndHead.
        Value is not specified by default.
    :arg str discover-pr-forks-strategy: Fork strategy. Valid options:
        merge-current, current, both, false. (default 'merge-current')
    :arg str discover-pr-forks-trust: Discovers pull requests where the origin
        repository is a fork of the target repository.
        Valid options: contributors, everyone, permission or nobody.
        (default 'contributors')
    :arg list build-strategies: Provides control over whether to build a branch
        (or branch like things such as change requests and tags) whenever it is
        discovered initially or a change from the previous revision has been
        detected. (optional)
        Refer to :func:`~build_strategies <build_strategies>`.
    :arg dict property-strategies: Provides control over how to build a branch
        (like to disable SCM triggering or to override the pipeline durability)
        (optional)
        Refer to :func:`~property_strategies <property_strategies>`.
    :arg bool local-branch: Check out to matching local branch
        If given, checkout the revision to build as HEAD on this branch.
        If selected, then the branch name is computed from the remote branch
        without the origin. In that case, a remote branch origin/master will
        be checked out to a local branch named master, and a remote branch
        origin/develop/new-feature will be checked out to a local branch
        named develop/newfeature.
        Requires the :jenkins-plugins:`Git Plugin <git>`.
    :arg list(str) refspecs: Which refspecs to look for.
    :arg dict checkout-over-ssh: Checkout repo over ssh.

        * **credentials** ('str'): Credentials to use for
            checkout of the repo over ssh.

    :arg dict filter-by-name-wildcard: Enable filter by name with wildcards.
        Requires the :jenkins-plugins:`SCM API Plugin <scm-api>`.

        * **includes** ('str'): Space-separated list
            of name patterns to consider. You may use * as a wildcard;
            for example: `master release*`
        * **excludes** ('str'): Name patterns to
            ignore even if matched by the includes list.
            For example: `release*`

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
        * **prune** (`bool`) - Prune remote branches (default false)
        * **shallow-clone** (`bool`) - Perform shallow clone (default false)
        * **sparse-checkout** (dict)
            * **paths** (list) - List of paths to sparse checkout. (optional)
        * **depth** (`int`) - Set shallow clone depth (default 1)
        * **do-not-fetch-tags** (`bool`) - Perform a clone without tags
            (default false)
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
        * **lfs-pull** (`bool`) - Call git lfs pull after checkout
            (default false)


    Minimal Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_bitbucket_minimal.yaml

    Full Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_bitbucket_full.yaml
    """
    source = XML.SubElement(
        xml_parent,
        "source",
        {
            "class": "com.cloudbees.jenkins.plugins.bitbucket.BitbucketSCMSource",
            "plugin": "cloudbees-bitbucket-branch-source",
        },
    )
    source_mapping = [
        ("", "id", "-".join(["bb", data.get("repo-owner", ""), data.get("repo", "")])),
        ("repo-owner", "repoOwner", None),
        ("repo", "repository", None),
    ]
    helpers.convert_mapping_to_xml(source, data, source_mapping, fail_required=True)

    mapping_optional = [
        ("credentials-id", "credentialsId", None),
        ("server-url", "serverUrl", None),
    ]
    helpers.convert_mapping_to_xml(source, data, mapping_optional, fail_required=False)

    traits = XML.SubElement(source, "traits")

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

    if data.get("discover-tags", False):
        XML.SubElement(
            traits, "com.cloudbees.jenkins.plugins.bitbucket.TagDiscoveryTrait"
        )

    if data.get("lfs", False):
        gitlfspull = XML.SubElement(
            traits, "jenkins.plugins.git.traits.GitLFSPullTrait", {"plugin": "git"}
        )
        XML.SubElement(
            gitlfspull,
            "extension",
            {"class": "hudson.plugins.git.extensions.impl.GitLFSPull"},
        )

    if data.get("head-filter-regex", None):
        rshf = XML.SubElement(traits, "jenkins.scm.impl.trait.RegexSCMHeadFilterTrait")
        XML.SubElement(rshf, "regex").text = data.get("head-filter-regex")

    if data.get("head-pr-filter-behaviors", None):
        add_filter_branch_pr_behaviors(traits, data.get("head-pr-filter-behaviors"))

    if data.get("discover-pr-origin", None):
        dpro = XML.SubElement(
            traits,
            "com.cloudbees.jenkins.plugins.bitbucket"
            ".OriginPullRequestDiscoveryTrait",
        )
        dpro_strategies = {"mergeOnly": "1", "headOnly": "2", "mergeAndHead": "3"}
        dpro_mapping = [("discover-pr-origin", "strategyId", None, dpro_strategies)]
        helpers.convert_mapping_to_xml(dpro, data, dpro_mapping, fail_required=True)

    if data.get("discover-pr-forks-strategy"):
        dprf = XML.SubElement(
            traits,
            "com.cloudbees.jenkins.plugins.bitbucket" ".ForkPullRequestDiscoveryTrait",
        )
        dprf_strategy = {"merge-current": "1", "current": "2", "both": "3"}
        dprf_mapping = [
            ("discover-pr-forks-strategy", "strategyId", "merge-current", dprf_strategy)
        ]
        helpers.convert_mapping_to_xml(dprf, data, dprf_mapping, fail_required=True)

        trust = data.get("discover-pr-forks-trust", "contributors")
        trust_map = {
            "contributors": "".join(
                [
                    "com.cloudbees.jenkins.plugins.bitbucket"
                    ".ForkPullRequestDiscoveryTrait$TrustContributors"
                ]
            ),
            "everyone": "".join(
                [
                    "com.cloudbees.jenkins.plugins.bitbucket"
                    ".ForkPullRequestDiscoveryTrait$TrustEveryone"
                ]
            ),
            "permission": "".join(
                [
                    "com.cloudbees.jenkins.plugins.bitbucket"
                    ".ForkPullRequestDiscoveryTrait$TrustPermission"
                ]
            ),
            "nobody": "".join(
                [
                    "com.cloudbees.jenkins.plugins.bitbucket"
                    ".ForkPullRequestDiscoveryTrait$TrustNobody"
                ]
            ),
        }
        if trust not in trust_map:
            raise InvalidAttributeError(
                "discover-pr-forks-trust", trust, trust_map.keys()
            )
        XML.SubElement(dprf, "trust").attrib["class"] = trust_map[trust]

    if data.get("discover-branch", None):
        dbr = XML.SubElement(
            traits, "com.cloudbees.jenkins.plugins.bitbucket.BranchDiscoveryTrait"
        )
        dbr_strategies = {"ex-pr": "1", "only-pr": "2", "all": "3"}
        dbr_mapping = [("discover-branch", "strategyId", None, dbr_strategies)]
        helpers.convert_mapping_to_xml(dbr, data, dbr_mapping, fail_required=True)

    if data.get("property-strategies", None):
        property_strategies(xml_parent, data)

    if data.get("build-strategies", None):
        build_strategies(xml_parent, data)

    if data.get("local-branch", False):
        lbr = XML.SubElement(
            traits, "jenkins.plugins.git.traits.LocalBranchTrait", {"plugin": "git"}
        )
        lbr_extension = XML.SubElement(
            lbr,
            "extension",
            {"class": "hudson.plugins.git.extensions.impl.LocalBranch"},
        )
        XML.SubElement(lbr_extension, "localBranch").text = "**"

    if data.get("checkout-over-ssh", None):
        cossh = XML.SubElement(
            traits, "com.cloudbees.jenkins.plugins.bitbucket.SSHCheckoutTrait"
        )
        cossh_credentials = [("credentials", "credentialsId", "")]
        helpers.convert_mapping_to_xml(
            cossh, data.get("checkout-over-ssh"), cossh_credentials, fail_required=True
        )

    add_filter_by_name_wildcard_behaviors(traits, data)

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


def gerrit_scm(xml_parent, data):
    r"""Configure Gerrit SCM

    Requires the :jenkins-plugins:`Gerrit Code Review Plugin
    <gerrit-code-review>`.

    :arg str url: The git url. (required)
    :arg str credentials-id: The credential to use to connect to the GIT URL.
    :arg bool ignore-on-push-notifications: If a job should not trigger upon
        push notifications. (default false)
    :arg list(str) refspecs: Which refspecs to look for.
        (default ``['+refs/changes/*:refs/remotes/@{remote}/*',
        '+refs/heads/*:refs/remotes/@{remote}/*']``)
    :arg str includes: Comma-separated list of branches to be included.
        (default '*')
    :arg str excludes: Comma-separated list of branches to be excluded.
        (default '')
    :arg str head-filter-regex: A regular expression for filtering
        discovered source branches. Requires the :jenkins-plugins:`SCM API
        Plugin <scm-api>`.
    :arg list build-strategies: Provides control over whether to build a branch
        (or branch like things such as change requests and tags) whenever it is
        discovered initially or a change from the previous revision has been
        detected. (optional)
        Refer to :func:`~build_strategies <build_strategies>`.
    :arg dict property-strategies: Provides control over how to build a branch
        (like to disable SCM triggering or to override the pipeline durability)
        (optional)
        Refer to :func:`~property_strategies <property_strategies>`.
    :arg dict filter-checks: Enable the filtering by pending checks, allowing to
        discover the changes that need validation only. This feature is using
        the gerrit checks plugin.
        (optional)
        query-operator: Name of the query operator, supported values are:
        'SCHEME' or 'ID'.
        query-string: Value of the query operator.
    :arg dict change-discovery: Configure the query string in 'Discover open changes'.
        The default 'p:<project> status:open -age:24w' will be added prior to the
        query-string specified here.
        (optional)
        query-string: Value of the query operator.

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
        * **prune** (`bool`) - Prune remote branches (default false)
        * **shallow-clone** (`bool`) - Perform shallow clone (default false)
        * **sparse-checkout** (dict)
            * **paths** (list) - List of paths to sparse checkout. (optional)
        * **depth** (`int`) - Set shallow clone depth (default 1)
        * **do-not-fetch-tags** (`bool`) - Perform a clone without tags
            (default false)
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
        * **lfs-pull** (`bool`) - Call git lfs pull after checkout
            (default false)

    Minimal Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_gerrit_minimal.yaml

    Full Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_gerrit_full.yaml
    """
    source = XML.SubElement(
        xml_parent,
        "source",
        {
            "class": "jenkins.plugins.gerrit.GerritSCMSource",
            "plugin": "gerrit-code-review",
        },
    )
    source_mapping = [
        ("", "id", "-".join(["gr", data.get("url", "")])),
        ("url", "remote", None),
        ("credentials-id", "credentialsId", ""),
        ("includes", "includes", "*"),
        ("excludes", "excludes", ""),
        ("ignore-on-push-notifications", "ignoreOnPushNotifications", True),
    ]
    helpers.convert_mapping_to_xml(source, data, source_mapping, fail_required=True)

    source_mapping_optional = [("api-uri", "apiUri", None)]
    helpers.convert_mapping_to_xml(
        source, data, source_mapping_optional, fail_required=False
    )

    # Traits
    traits = XML.SubElement(source, "traits")
    change_discovery_trait = XML.SubElement(
        traits, "jenkins.plugins.gerrit.traits.ChangeDiscoveryTrait"
    )
    change_discovery = data.get("change-discovery", None)
    if change_discovery:
        change_discovery_mapping = [("query-string", "queryString", None)]
        helpers.convert_mapping_to_xml(
            change_discovery_trait,
            change_discovery,
            change_discovery_mapping,
            fail_required=True,
        )

    # Refspec Trait
    refspec_trait = XML.SubElement(
        traits, "jenkins.plugins.git.traits.RefSpecsSCMSourceTrait", {"plugin": "git"}
    )
    templates = XML.SubElement(refspec_trait, "templates")
    refspecs = data.get(
        "refspecs",
        [
            "+refs/changes/*:refs/remotes/@{remote}/*",
            "+refs/heads/*:refs/remotes/@{remote}/*",
        ],
    )
    # convert single string to list
    if isinstance(refspecs, six.string_types):
        refspecs = [refspecs]
    for x in refspecs:
        e = XML.SubElement(
            templates,
            ("jenkins.plugins.git.traits" ".RefSpecsSCMSourceTrait_-RefSpecTemplate"),
        )
        XML.SubElement(e, "value").text = x

    if data.get("property-strategies", None):
        property_strategies(xml_parent, data)

    if data.get("build-strategies", None):
        build_strategies(xml_parent, data)

    if data.get("head-filter-regex", None):
        rshf = XML.SubElement(traits, "jenkins.scm.impl.trait.RegexSCMHeadFilterTrait")
        XML.SubElement(rshf, "regex").text = data.get("head-filter-regex")

    # FilterChecks Trait
    checks = data.get("filter-checks", None)
    if checks:
        checks_trait = XML.SubElement(
            traits, "jenkins.plugins.gerrit.traits.FilterChecksTrait"
        )
        checks_source_mapping = [
            ("query-operator", "queryOperator", None),
            ("query-string", "queryString", None),
        ]
        helpers.convert_mapping_to_xml(
            checks_trait, checks, checks_source_mapping, fail_required=True
        )

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


def git_scm(xml_parent, data):
    r"""Configure Git SCM

    Requires the :jenkins-plugins:`Git Plugin <git>`.

    :arg str url: The git repo url. (required)
    :arg str credentials-id: The credential to use to connect to the GIT repo.
        (default '')

    :arg bool discover-branches: Discovers branches on the repository.
        (default true)
    :arg bool discover-tags: Discovers tags on the repository.
        (default false)
    :arg bool ignore-on-push-notifications: If a job should not trigger upon
        push notifications. (default false)
    :arg str head-filter-regex: A regular expression for filtering
        discovered source branches. Requires the :jenkins-plugins:`SCM API
        Plugin <scm-api>`.
    :arg list head-pr-filter-behaviors: Definition of Filter Branch PR behaviors.
        Requires the :jenkins-plugins:`SCM Filter Branch PR Plugin
        <scm-filter-branch-pr>`.
        Refer to :func:`~add_filter_branch_pr_behaviors <add_filter_branch_pr_behaviors>`.
    :arg list build-strategies: Provides control over whether to build a branch
        (or branch like things such as change requests and tags) whenever it is
        discovered initially or a change from the previous revision has been
        detected. (optional)
        Refer to :func:`~build_strategies <build_strategies>`.
    :arg dict property-strategies: Provides control over how to build a branch
        (like to disable SCM triggering or to override the pipeline durability)
        (optional)
        Refer to :func:`~property_strategies <property_strategies>`.

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
        * **prune** (`bool`) - Prune remote branches (default false)
        * **shallow-clone** (`bool`) - Perform shallow clone (default false)
        * **sparse-checkout** (dict)
            * **paths** (list) - List of paths to sparse checkout. (optional)
        * **depth** (`int`) - Set shallow clone depth (default 1)
        * **do-not-fetch-tags** (`bool`) - Perform a clone without tags
            (default false)
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
        * **lfs-pull** (`bool`) - Call git lfs pull after checkout
            (default false)

    Minimal Example:

    .. literalinclude:: /../../tests/multibranch/fixtures/scm_git_minimal.yaml

    Full Example:

    .. literalinclude:: /../../tests/multibranch/fixtures/scm_git_full.yaml
    """
    source = XML.SubElement(
        xml_parent,
        "source",
        {"class": "jenkins.plugins.git.GitSCMSource", "plugin": "git"},
    )
    source_mapping = [
        ("", "id", "-".join(["gt", data.get("url", "")])),
        ("url", "remote", None),
        ("credentials-id", "credentialsId", ""),
    ]
    helpers.convert_mapping_to_xml(source, data, source_mapping, fail_required=True)

    ##########
    # Traits #
    ##########

    traits_path = "jenkins.plugins.git.traits"
    traits = XML.SubElement(source, "traits")

    if data.get("discover-branches", True):
        XML.SubElement(traits, "".join([traits_path, ".BranchDiscoveryTrait"]))

    if data.get("discover-tags", False):
        XML.SubElement(traits, "".join([traits_path, ".TagDiscoveryTrait"]))

    if data.get("ignore-on-push-notifications", False):
        XML.SubElement(traits, "".join([traits_path, ".IgnoreOnPushNotificationTrait"]))

    if data.get("head-filter-regex", None):
        rshf = XML.SubElement(traits, "jenkins.scm.impl.trait.RegexSCMHeadFilterTrait")
        XML.SubElement(rshf, "regex").text = data.get("head-filter-regex")

    if data.get("head-pr-filter-behaviors", None):
        add_filter_branch_pr_behaviors(traits, data.get("head-pr-filter-behaviors"))

    if data.get("property-strategies", None):
        property_strategies(xml_parent, data)

    if data.get("build-strategies", None):
        build_strategies(xml_parent, data)

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


def github_scm(xml_parent, data):
    r"""Configure GitHub SCM

    Requires the :jenkins-plugins:`GitHub Branch Source Plugin
    <github-branch-source>`.

    :arg str api-uri: The GitHub API uri for hosted / on-site GitHub. Must
        first be configured in Global Configuration. (default GitHub)
    :arg bool ssh-checkout: Checkout over SSH.

        * **credentials** ('str'): Credentials to use for
            checkout of the repo over ssh.

    :arg str credentials-id: Credentials used to scan branches and pull
        requests, check out sources and mark commit statuses. (optional)
    :arg str repo-owner: Specify the name of the GitHub Organization or
        GitHub User Account. (required)
    :arg str repo: The GitHub repo. (required)

    :arg str branch-discovery: Discovers branches on the repository.
        Valid options: no-pr, only-pr, all, false. (default 'no-pr')
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
        <scm-filter-branch-pr>`.
        Refer to :func:`~add_filter_branch_pr_behaviors <add_filter_branch_pr_behaviors>`.
    :arg list build-strategies: Provides control over whether to build a branch
        (or branch like things such as change requests and tags) whenever it is
        discovered initially or a change from the previous revision has been
        detected. (optional)
        Refer to :func:`~build_strategies <build_strategies>`.
    :arg dict notification-context: Change the default GitHub check notification
        context from "continuous-integration/jenkins/SUFFIX" to a custom label / suffix.
        (set a label and suffix to true or false, optional)
        Requires the :jenkins-plugins:`Github Custom Notification Context SCM
        Behaviour <github-scm-trait-notification-context>`.
        Refer to :func:`~add_notification_context_trait <add_notification_context_trait>`.
    :arg dict property-strategies: Provides control over how to build a branch
        (like to disable SCM triggering or to override the pipeline durability)
        (optional)
        Refer to :func:`~property_strategies <property_strategies>`.
    :arg dict filter-by-name-wildcard: Enable filter by name with wildcards.
        Requires the :jenkins-plugins:`SCM API Plugin <scm-api>`.

        * **includes** ('str'): Space-separated list
            of name patterns to consider. You may use * as a wildcard;
            for example: `master release*`
        * **excludes** ('str'): Name patterns to
            ignore even if matched by the includes list.
            For example: `release*`

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
        * **prune** (`bool`) - Prune remote branches (default false)
        * **shallow-clone** (`bool`) - Perform shallow clone (default false)
        * **sparse-checkout** (dict)
            * **paths** (list) - List of paths to sparse checkout. (optional)
        * **depth** (`int`) - Set shallow clone depth (default 1)
        * **do-not-fetch-tags** (`bool`) - Perform a clone without tags
            (default false)
        * **disable-pr-notifications** (`bool`) - Disable default github status
            notifications on pull requests (default false) (Requires the
            :jenkins-plugins:`GitHub Branch Source Plugin
            <disable-github-multibranch-status>`.)
        * **refspecs** (`list(str)`): Which refspecs to fetch.
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
        * **lfs-pull** (`bool`) - Call git lfs pull after checkout
            (default false)

    Minimal Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_github_minimal.yaml

    Full Example:

    .. literalinclude::
       /../../tests/multibranch/fixtures/scm_github_full.yaml
    """
    github_path = "org.jenkinsci.plugins.github_branch_source"
    github_path_dscore = "org.jenkinsci.plugins.github__branch__source"

    source = XML.SubElement(
        xml_parent,
        "source",
        {
            "class": "".join([github_path, ".GitHubSCMSource"]),
            "plugin": "github-branch-source",
        },
    )
    mapping = [
        ("", "id", "-".join(["gh", data.get("repo-owner", ""), data.get("repo", "")])),
        ("repo-owner", "repoOwner", None),
        ("repo", "repository", None),
    ]
    helpers.convert_mapping_to_xml(source, data, mapping, fail_required=True)

    mapping_optional = [
        ("api-uri", "apiUri", None),
        ("credentials-id", "credentialsId", None),
    ]
    helpers.convert_mapping_to_xml(source, data, mapping_optional, fail_required=False)

    traits = XML.SubElement(source, "traits")

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

    if data.get("head-pr-filter-behaviors", None):
        add_filter_branch_pr_behaviors(traits, data.get("head-pr-filter-behaviors"))

    if data.get("property-strategies", None):
        property_strategies(xml_parent, data)

    if data.get("build-strategies", None):
        build_strategies(xml_parent, data)

    add_github_checks_traits(traits, data)
    add_notification_context_trait(traits, data)
    add_filter_by_name_wildcard_behaviors(traits, data)

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


def build_strategies(xml_parent, data):
    """Configure Basic Branch Build Strategies.

    Requires the :jenkins-plugins:`Basic Branch Build Strategies Plugin
    <basic-branch-build-strategies>`.

    Other build strategies can be configured via raw XML injection.

    :arg list build-strategies: Definition of build strategies.

        * **all-strategies-match** (dict): All sub strategies must match for
            this strategy to match.
            * **strategies** (list): Sub strategies
        * **any-strategies-match** (dict): Builds whenever any of the sub
            strategies match.
            * **strategies** (list): Sub strategies
        * **tags** (dict): Builds tags
            * **ignore-tags-newer-than** (int) The number of days since the tag
                was created before it is eligible for automatic building.
                (optional, default -1)
            * **ignore-tags-older-than** (int) The number of days since the tag
                was created after which it is no longer eligible for automatic
                building. (optional, default -1)
        * **change-request** (dict): Builds change requests / pull requests
            * **ignore-target-only-changes** (bool) Ignore rebuilding merge
                branches when only the target branch changed.
                (optional, default false)
        * **regular-branches** (bool): Builds regular branches whenever a
            change is detected. (optional, default None)
        * **skip-initial-build** (bool): Skip initial build on first branch
            indexing. (optional, default None)
        * **named-branches** (list): Builds named branches whenever a change
          is detected.

            * **exact-name** (dict) Matches the name verbatim.
                * **name** (str) The name to match. (optional)
                * **case-sensitive** (bool) Check this box if the name should
                    be matched case sensitively. (default false)
            * **regex-name** (dict) Matches the name against a regular
              expression.

                * **regex** (str) A Java regular expression to restrict the
                    names. Names that do not match the supplied regular
                    expression will be ignored. (default `^.*$`)
                * **case-sensitive** (bool) Check this box if the name should
                    be matched case sensitively. (default false)
            * **wildcards-name** (dict) Matches the name against an
              include/exclude set of wildcards.

                * **includes** (str) Space-separated list of name patterns to
                    consider. You may use `*` as a wildcard;
                    for example: `master release*` (default `*`)
                * **excludes** (str) Name patterns to ignore even if matched
                    by the includes list. For example: release (optional)
        * **raw** (dict): Injects raw BuildStrategy XML to use other build
            strategy plugins.

    """

    basic_build_strategies = "jenkins.branch.buildstrategies.basic"
    if data.get("build-strategies", None):
        bbs_data = data.get("build-strategies", None)
        bbs = XML.SubElement(xml_parent, "buildStrategies")
    else:
        bbs_data = data.get("strategies", None)
        bbs = XML.SubElement(xml_parent, "strategies")
    for bbs_list in bbs_data:
        if "all-strategies-match" in bbs_list:
            all_elem = XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".AllBranchBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )
            build_strategies(all_elem, bbs_list["all-strategies-match"])

        if "any-strategies-match" in bbs_list:
            any_elem = XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".AnyBranchBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )
            build_strategies(any_elem, bbs_list["any-strategies-match"])

        if "tags" in bbs_list:
            tags = bbs_list["tags"]
            tags_elem = XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".TagBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )

            newer_than = -1
            if "ignore-tags-newer-than" in tags and tags["ignore-tags-newer-than"] >= 0:
                newer_than = str(tags["ignore-tags-newer-than"] * 86400000)
            XML.SubElement(tags_elem, "atLeastMillis").text = str(newer_than)

            older_than = -1
            if "ignore-tags-older-than" in tags and tags["ignore-tags-older-than"] >= 0:
                older_than = str(tags["ignore-tags-older-than"] * 86400000)
            XML.SubElement(tags_elem, "atMostMillis").text = str(older_than)

        if bbs_list.get("regular-branches", False):
            XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".BranchBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )

        if bbs_list.get("skip-initial-build", False):
            XML.SubElement(
                bbs,
                "".join(
                    [basic_build_strategies, ".SkipInitialBuildOnFirstBranchIndexing"]
                ),
                {"plugin": "basic-branch-build-strategies"},
            )

        if "change-request" in bbs_list:
            cr = bbs_list["change-request"]
            cr_elem = XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".ChangeRequestBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )
            itoc = cr.get("ignore-target-only-changes", False)
            XML.SubElement(cr_elem, "ignoreTargetOnlyChanges").text = str(itoc).lower()

        if "named-branches" in bbs_list:
            named_branch_elem = XML.SubElement(
                bbs,
                "".join([basic_build_strategies, ".NamedBranchBuildStrategyImpl"]),
                {"plugin": "basic-branch-build-strategies"},
            )

            filters = XML.SubElement(named_branch_elem, "filters")

            for nb in bbs_list["named-branches"]:
                if "exact-name" in nb:
                    exact_name_elem = XML.SubElement(
                        filters,
                        "".join(
                            [
                                basic_build_strategies,
                                ".NamedBranchBuildStrategyImpl",
                                "_-ExactNameFilter",
                            ]
                        ),
                    )
                    exact_name_mapping = [
                        ("name", "name", ""),
                        ("case-sensitive", "caseSensitive", False),
                    ]
                    helpers.convert_mapping_to_xml(
                        exact_name_elem,
                        nb["exact-name"],
                        exact_name_mapping,
                        fail_required=False,
                    )

                if "regex-name" in nb:
                    regex_name_elem = XML.SubElement(
                        filters,
                        "".join(
                            [
                                basic_build_strategies,
                                ".NamedBranchBuildStrategyImpl",
                                "_-RegexNameFilter",
                            ]
                        ),
                    )
                    regex_name_mapping = [
                        ("regex", "regex", "^.*$"),
                        ("case-sensitive", "caseSensitive", False),
                    ]
                    helpers.convert_mapping_to_xml(
                        regex_name_elem,
                        nb["regex-name"],
                        regex_name_mapping,
                        fail_required=False,
                    )

                if "wildcards-name" in nb:
                    wildcards_name_elem = XML.SubElement(
                        filters,
                        "".join(
                            [
                                basic_build_strategies,
                                ".NamedBranchBuildStrategyImpl",
                                "_-WildcardsNameFilter",
                            ]
                        ),
                    )
                    wildcards_name_mapping = [
                        ("includes", "includes", "*"),
                        ("excludes", "excludes", ""),
                    ]
                    helpers.convert_mapping_to_xml(
                        wildcards_name_elem,
                        nb["wildcards-name"],
                        wildcards_name_mapping,
                        fail_required=False,
                    )

        if "raw" in bbs_list:
            raw_xml = XML.fromstring(bbs_list["raw"].get("xml"))
            remove_ignorable_whitespace(raw_xml)
            XML.SubElement(bbs, None).append(raw_xml)


def property_strategies(xml_parent, data):
    """Configure Basic Branch Property Strategies.

    Requires the :jenkins-plugins:`Branch API Plugin <branch-api>`.

    :arg dict property-strategies: Definition of property strategies.  Either
        `named-branches` or `all-branches` may be specified, but not both.

        * **all-branches** (list): A list of property strategy definitions
            for use with all branches.

            * **suppress-scm-triggering** (dict):
                Suppresses automatic SCM triggering (optional).

                * **branch-regex** (str):
                    Regex matching branch names.
                    Only these branches will be affected by the selected
                    suppression strategy. Default ``^$``.
                * **suppress-strategy** (str):
                    Select what to suppress for branches matching the regex.
                    Valid values: ``suppress-nothing`` (default),
                    ``suppress-branch-indexing``, or ``suppress-webhooks``.

                    .. note::
                        Using ``suppress-scm-triggering: true`` is deprecated
                        since Branch API 2.1045.v4ec3ed07b_e4f.
            * **pipeline-branch-durability-override** (str): Set a custom
                branch speed/durability level. Valid values:
                performance-optimized, survivable-nonatomic, or
                max-survivability (optional)
                Requires the :jenkins-plugins:`Pipeline Multibranch Plugin
                <workflow-multibranch>`
            * **trigger-build-on-pr-comment** (str or dict): The comment body to
                trigger a new build for a PR job when it is received. This
                is compiled as a case-insensitive regular expression, so
                use ``".*"`` to trigger a build on any comment whatsoever.
                (optional)
                If dictionary syntax is used, the option requires 2 fields:
                ``comment`` with the comment body and ``allow-untrusted-users``
                (bool) causing the plugin to skip checking if the comment author
                is a collaborator of the GitHub project.
                Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                <github-pr-comment-build>`
            * **trigger-build-on-pr-review** (bool or dict): This property will
                cause a job for a pull request ``(PR-*)`` to be triggered
                immediately when a review is made on the PR in GitHub.
                This has no effect on jobs that are not for pull requests.
                (optional)
                If dictionary syntax is used, the option requires
                ``allow-untrusted-users`` (bool) causing the plugin to skip
                checking if the review author is a collaborator of the GitHub
                project.
                Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                <github-pr-comment-build>`
            * **trigger-build-on-pr-update** (bool or dict): This property will
                cause a job for a pull request ``(PR-*)`` to be triggered
                immediately when the PR title or description is edited in
                GitHub. This has no effect on jobs that are not for pull
                requests. (optional)
                If dictionary syntax is used, the option requires
                ``allow-untrusted-users`` (bool) causing the plugin to skip
                checking if the update author is a collaborator of the GitHub
                project.
                Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                <github-pr-comment-build>`
        * **named-branches** (dict): Named branches get different properties.
            Comprised of a list of defaults and a list of property strategy
            exceptions for use with specific branches.

            * **defaults** (list): A list of property strategy definitions
                to be applied by default to all branches, unless overridden
                by an entry in `exceptions`

                * **suppress-scm-triggering** (dict):
                    Suppresses automatic SCM triggering (optional).

                    * **branch-regex** (str):
                        Regex matching branch names.
                        Only these branches will be affected by the selected
                        suppression strategy. Default ``^$``.
                    * **suppress-strategy** (str):
                        Select what to suppress for branches matching the regex.
                        Valid values: ``suppress-nothing`` (default),
                        ``suppress-branch-indexing``, or ``suppress-webhooks``.

                        .. note::
                            Using ``suppress-scm-triggering: true`` is deprecated
                            since Branch API 2.1045.v4ec3ed07b_e4f.
                * **pipeline-branch-durability-override** (str): Set a custom
                    branch speed/durability level. Valid values:
                    performance-optimized, survivable-nonatomic, or
                    max-survivability (optional)
                    Requires the :jenkins-plugins:`Pipeline Multibranch Plugin
                    <workflow-multibranch>`
                * **trigger-build-on-pr-comment** (str or dict): The comment body to
                    trigger a new build for a PR job when it is received. This
                    is compiled as a case-insensitive regular expression, so
                    use ``".*"`` to trigger a build on any comment whatsoever.
                    (optional)
                    If dictionary syntax is used, the option accepts 2 fields:
                    ``comment`` (str, required) with the comment body and
                    ``allow-untrusted-users`` (bool, optional) causing the plugin
                    to skip checking if the comment author is a collaborator of
                    the GitHub project.
                    Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                    <github-pr-comment-build>`
                * **trigger-build-on-pr-review** (bool or dict): This property will
                    cause a job for a pull request ``(PR-*)`` to be triggered
                    immediately when a review is made on the PR in GitHub.
                    This has no effect on jobs that are not for pull requests.
                    (optional)
                    If dictionary syntax is used, the option requires
                    ``allow-untrusted-users`` (bool) causing the plugin to skip
                    checking if the review author is a collaborator of the GitHub
                    project.
                    Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                    <github-pr-comment-build>`
                * **trigger-build-on-pr-update** (bool or dict): This property will
                    cause a job for a pull request ``(PR-*)`` to be triggered
                    immediately when the PR title or description is edited in
                    GitHub. This has no effect on jobs that are not for pull
                    requests. (optional)
                    If dictionary syntax is used, the option requires
                    ``allow-untrusted-users`` (bool) causing the plugin to skip
                    checking if the update author is a collaborator of the GitHub
                    project.
                    Requires the :jenkins-plugins:`GitHub PR Comment Build Plugin
                    <github-pr-comment-build>`

            * **exceptions** (list): A list of branch names and the property
                strategies to be used on that branch, instead of any listed
                in `defaults`.

                * **exception** (dict): Defines exception
                    * **branch-name** (str): Name of the branch to which these
                        properties will be applied.
                    * **properties** (list): A list of properties to apply to
                        this branch.

                        * **suppress-scm-triggering** (dict):
                            Suppresses automatic SCM triggering (optional).

                            * **branch-regex** (str):
                                Regex matching branch names.
                                Only these branches will be affected by the selected
                                suppression strategy. Default ``^$``.
                            * **suppress-strategy** (str):
                                Select what to suppress for branches matching the regex.
                                Valid values: ``suppress-nothing`` (default),
                                ``suppress-branch-indexing``, or ``suppress-webhooks``.

                                .. note::
                                    Using ``suppress-scm-triggering: true`` is deprecated
                                    since Branch API 2.1045.v4ec3ed07b_e4f.

                        * **pipeline-branch-durability-override** (str): Set a
                            custom branch speed/durability level. Valid values:
                            performance-optimized, survivable-nonatomic, or
                            max-survivability (optional)
                            Requires the :jenkins-plugins:`Pipeline
                            Multibranch Plugin <workflow-multibranch>`
    """

    valid_prop_strats = ["all-branches", "named-branches"]

    basic_property_strategies = "jenkins.branch"

    prop_strats = data.get("property-strategies", None)

    if prop_strats:

        for prop_strat in prop_strats:
            if prop_strat not in valid_prop_strats:
                raise InvalidAttributeError(
                    "property-strategies", prop_strat, valid_prop_strats
                )
        if len(prop_strats) > 1:
            raise JenkinsJobsException("Only one property strategy may be specified")

        all_branches = prop_strats.get("all-branches", None)
        named_branches = prop_strats.get("named-branches", None)

        if all_branches:

            strat_elem = XML.SubElement(
                xml_parent,
                "strategy",
                {
                    "class": "".join(
                        [basic_property_strategies, ".DefaultBranchPropertyStrategy"]
                    )
                },
            )
            props_elem = XML.SubElement(
                strat_elem, "properties", {"class": "java.util.Arrays$ArrayList"}
            )
            props_elem = XML.SubElement(
                props_elem,
                "a",
                {
                    "class": "".join(
                        [basic_property_strategies, ".BranchProperty-array"]
                    )
                },
            )

            apply_property_strategies(props_elem, all_branches)

        elif named_branches:

            strat_elem = XML.SubElement(
                xml_parent,
                "strategy",
                {
                    "class": "".join(
                        [
                            basic_property_strategies,
                            ".NamedExceptionsBranchPropertyStrategy",
                        ]
                    )
                },
            )

            nbs_defaults = named_branches.get("defaults", None)
            if nbs_defaults:

                props_elem = XML.SubElement(
                    strat_elem,
                    "defaultProperties",
                    {"class": "java.util.Arrays$ArrayList"},
                )
                props_elem = XML.SubElement(
                    props_elem,
                    "a",
                    {
                        "class": "".join(
                            [basic_property_strategies, ".BranchProperty-array"]
                        )
                    },
                )

                apply_property_strategies(props_elem, nbs_defaults)

            nbs_exceptions = named_branches.get("exceptions", None)
            if nbs_exceptions:

                props_elem = XML.SubElement(
                    strat_elem,
                    "namedExceptions",
                    {"class": "java.util.Arrays$ArrayList"},
                )
                props_elem = XML.SubElement(
                    props_elem,
                    "a",
                    {
                        "class": "".join(
                            [
                                basic_property_strategies,
                                ".NamedExceptionsBranchPropertyStrategy$Named-array",
                            ]
                        )
                    },
                )

                for named_exception in nbs_exceptions:
                    named_exception = named_exception.get("exception", None)
                    if not named_exception:
                        continue

                    exc_elem = XML.SubElement(
                        props_elem,
                        "".join(
                            [
                                basic_property_strategies,
                                ".NamedExceptionsBranchPropertyStrategy_-Named",
                            ]
                        ),
                    )

                    ne_branch_name = named_exception.get("branch-name", None)
                    if ne_branch_name is not None:
                        XML.SubElement(exc_elem, "name").text = ne_branch_name

                    ne_properties = named_exception.get("properties", None)
                    if ne_properties:
                        exc_elem = XML.SubElement(
                            exc_elem, "props", {"class": "java.util.Arrays$ArrayList"}
                        )
                        exc_elem = XML.SubElement(
                            exc_elem,
                            "a",
                            {
                                "class": "".join(
                                    [basic_property_strategies, ".BranchProperty-array"]
                                )
                            },
                        )
                        apply_property_strategies(exc_elem, ne_properties)


def apply_property_strategies(props_elem, props_list):
    # there are 3 locations at which property strategies can be defined:
    # globally (all-branches), defaults (named-branches), exceptions
    # (also named-branches)

    basic_property_strategies = "jenkins.branch"
    workflow_multibranch = "org.jenkinsci.plugins.workflow.multibranch"
    pr_comment_build = "com.adobe.jenkins.github__pr__comment__build"
    # Valid options for the pipeline branch durability override.
    pbdo_map = collections.OrderedDict(
        [
            ("max-survivability", "MAX_SURVIVABILITY"),
            ("performance-optimized", "PERFORMANCE_OPTIMIZED"),
            ("survivable-nonatomic", "SURVIVABLE_NONATOMIC"),
        ]
    )

    pcb_bool_opts = collections.OrderedDict(
        [
            ("trigger-build-on-pr-review", ".TriggerPRReviewBranchProperty"),
            ("trigger-build-on-pr-update", ".TriggerPRUpdateBranchProperty"),
        ]
    )

    # valid options for suppress SCM trigger property
    # strategy name says what's blocked
    sst_map = collections.OrderedDict(
        [
            ("suppress-nothing", "NONE"),
            ("suppress-webhooks", "EVENTS"),
            ("suppress-branch-indexing", "INDEXING"),
        ]
    )

    for dbs_list in props_list:

        sst_val = dbs_list.get("suppress-scm-triggering", False)
        if sst_val:
            sst_elem = XML.SubElement(
                props_elem,
                "".join([basic_property_strategies, ".NoTriggerBranchProperty"]),
            )

            if isinstance(sst_val, dict):
                if "branch-regex" not in sst_val:
                    raise MissingAttributeError("suppress-scm-triggering[branch-regex]")
                if "suppression-strategy" not in sst_val:
                    raise MissingAttributeError(
                        "suppress-scm-triggering[suppression-strategy]"
                    )

                sst_ss_val = sst_val["suppression-strategy"]
                if not sst_map.get(sst_ss_val):
                    raise InvalidAttributeError(
                        "suppression-strategy", sst_ss_val, sst_map.keys()
                    )
                XML.SubElement(sst_elem, "triggeredBranchesRegex").text = sst_val[
                    "branch-regex"
                ]
                XML.SubElement(sst_elem, "strategy").text = sst_map[sst_ss_val]

            elif isinstance(sst_val, bool):
                # no sub-elements in this case
                pass
            else:
                raise InvalidAttributeError("suppress-scm-triggering", sst_val)

        pbdo_val = dbs_list.get("pipeline-branch-durability-override", None)
        if pbdo_val:
            if not pbdo_map.get(pbdo_val):
                raise InvalidAttributeError(
                    "pipeline-branch-durability-override", pbdo_val, pbdo_map.keys()
                )
            pbdo_elem = XML.SubElement(
                props_elem,
                "".join([workflow_multibranch, ".DurabilityHintBranchProperty"]),
                {"plugin": "workflow-multibranch"},
            )
            XML.SubElement(pbdo_elem, "hint").text = pbdo_map.get(pbdo_val)

        tbopc_val = dbs_list.get("trigger-build-on-pr-comment", None)
        if tbopc_val:
            tbopc_elem = XML.SubElement(
                props_elem,
                "".join([pr_comment_build, ".TriggerPRCommentBranchProperty"]),
                {"plugin": "github-pr-comment-build"},
            )
            if isinstance(tbopc_val, dict):
                if "comment" not in tbopc_val:
                    raise MissingAttributeError(
                        "trigger-build-on-pr-comment[comment]",
                        pos=dbs_list.key_pos.get("trigger-build-on-pr-comment"),
                    )
                XML.SubElement(tbopc_elem, "commentBody").text = tbopc_val["comment"]
                if tbopc_val.get("allow-untrusted-users", False):
                    XML.SubElement(tbopc_elem, "allowUntrusted").text = "true"
            elif isinstance(tbopc_val, str):
                XML.SubElement(tbopc_elem, "commentBody").text = tbopc_val
            else:
                attr = "trigger-build-on-pr-comment"
                ctx = [Context(f"For attribute {attr!r}", dbs_list.key_pos.get(attr))]
                raise InvalidAttributeError(
                    attr,
                    tbopc_val,
                    pos=dbs_list.value_pos.get(attr),
                    ctx=ctx,
                )
        for opt in pcb_bool_opts:
            opt_value = dbs_list.get(opt, None)
            if opt_value:
                opt_elem = XML.SubElement(
                    props_elem,
                    "".join([pr_comment_build, pcb_bool_opts.get(opt)]),
                    {"plugin": "github-pr-comment-build"},
                )
                if isinstance(opt_value, dict):
                    if opt_value.get("allow-untrusted-users", False):
                        XML.SubElement(opt_elem, "allowUntrusted").text = "true"
                elif isinstance(opt_value, bool):
                    # no sub-elements in this case
                    pass
                else:
                    ctx = Context(f"For attribute {opt!r}", dbs_list.key_pos.get(opt))
                    raise InvalidAttributeError(
                        opt, opt_value, pos=dbs_list.value_pos.get(opt), ctx=[ctx]
                    )


def add_filter_branch_pr_behaviors(traits, data):
    """Configure Filter Branch PR behaviors

    Requires the :jenkins-plugins:`SCM Filter Branch PR Plugin
    <scm-filter-branch-pr>`.

    :arg list head-pr-filter-behaviors: Definition of filters.

        * **head-pr-destined-regex** (dict): Filter by name incl. PR destined to
            this branch with regexp

            * **branch-regexp** (str) Regular expression to filter branches and
                PRs (optional, default ".*")
            * **tag-regexp** (str) Regular expression to filter tags
                (optional, default "(?!.*)")

        * **head-pr-destined-wildcard** (dict): Filter by name incl. PR
            destined to this branch with wildcard

            * **branch-includes** (str) Wildcard expression to include branches
                and PRs (optional, default "*")
            * **tag-includes** (str) Wildcard expression to include tags
                (optional, default "")
            * **branch-excludes** (str) Wildcard expression to exclude branches
                and PRs (optional, default "")
            * **tag-excludes** (str) Wildcard expression to exclude tags
                (optional, default "*")

        * **head-pr-originated-regex** (dict): Filter by name incl. PR destined
            to this branch with regexp

            * **branch-regexp** (str) Regular expression to filter branches
                and PRs (optional, default ".*")
            * **tag-regexp** (str) Regular expression to filter tags
                (optional, default "(?!.*)")

        * **head-pr-originated-wildcard** (dict): Filter by name incl. PR
            destined to this branch with wildcard

            * **branch-includes** (str) Wildcard expression to include branches
                and PRs (optional, default "*")
            * **tag-includes** (str) Wildcard expression to include tags
                (optional, default "")
            * **branch-excludes** (str) Wildcard expression to exclude branches
                and PRs (optional, default "")
            * **tag-excludes** (str) Wildcard expression to exclude tags
                (optional, default "*")
    """

    regexp_mapping = [
        ("branch-regexp", "regex", ".*"),
        ("tag-regexp", "tagRegex", "(?!.*)"),
    ]
    wildcard_mapping = [
        ("branch-includes", "includes", "*"),
        ("branch-excludes", "excludes", ""),
        ("tag-includes", "tagIncludes", ""),
        ("tag-excludes", "tagExcludes", "*"),
    ]

    if data.get("head-pr-destined-regex"):
        rshf = XML.SubElement(
            traits,
            "net.gleske.scmfilter.impl.trait.RegexSCMHeadFilterTrait",
            {"plugin": "scm-filter-branch-pr"},
        )
        helpers.convert_mapping_to_xml(
            rshf, data.get("head-pr-destined-regex"), regexp_mapping, fail_required=True
        )

    if data.get("head-pr-destined-wildcard"):
        wshf = XML.SubElement(
            traits,
            "net.gleske.scmfilter.impl.trait.WildcardSCMHeadFilterTrait",
            {"plugin": "scm-filter-branch-pr"},
        )
        helpers.convert_mapping_to_xml(
            wshf,
            data.get("head-pr-destined-wildcard"),
            wildcard_mapping,
            fail_required=True,
        )

    if data.get("head-pr-originated-regex"):
        rsof = XML.SubElement(
            traits,
            "net.gleske.scmfilter.impl.trait.RegexSCMOriginFilterTrait",
            {"plugin": "scm-filter-branch-pr"},
        )
        helpers.convert_mapping_to_xml(
            rsof,
            data.get("head-pr-originated-regex"),
            regexp_mapping,
            fail_required=True,
        )

    if data.get("head-pr-originated-wildcard"):
        wsof = XML.SubElement(
            traits,
            "net.gleske.scmfilter.impl.trait.WildcardSCMOriginFilterTrait",
            {"plugin": "scm-filter-branch-pr"},
        )
        helpers.convert_mapping_to_xml(
            wsof,
            data.get("head-pr-originated-wildcard"),
            wildcard_mapping,
            fail_required=True,
        )


def add_filter_by_name_wildcard_behaviors(traits, data):
    """Configure branch filtering behaviors.

    :arg dict filter-by-name-wildcard: Enable filter by name with wildcards.
        Requires the :jenkins-plugins:`SCM API Plugin <scm-api>`.

        * **includes** ('str'): Space-separated list
            of name patterns to consider. You may use * as a wildcard;
            for example: `master release*`
        * **excludes** ('str'): Name patterns to
            ignore even if matched by the includes list.
            For example: `release*`
    """
    if data.get("filter-by-name-wildcard", None):
        wscmf_name = XML.SubElement(
            traits,
            "jenkins.scm.impl.trait.WildcardSCMHeadFilterTrait",
            {"plugin": "scm-api"},
        )
        wscmf_name_mapping = [
            ("includes", "includes", ""),
            ("excludes", "excludes", ""),
        ]
        helpers.convert_mapping_to_xml(
            wscmf_name,
            data.get("filter-by-name-wildcard", ""),
            wscmf_name_mapping,
            fail_required=True,
        )


def add_notification_context_trait(traits, data):
    """Change the default GitHub check notification context from
    "continuous-integration/jenkins/SUFFIX" to a custom label / suffix.
    (set a label and suffix to true or false, optional)

    Requires the :jenkins-plugins:`Github Custom Notification Context SCM
    Behaviour <github-scm-trait-notification-context>`.

    :arg dict notification-context: Definition of notification-context. A
        `label` must be specified. `suffix` may be specified with true /
        false, default being true.

        * **label** (str): The text of the context label for Github status
            notifications.
        * **suffix** (bool): Appends the relevant suffix to the context label
            based on the build type. '/pr-merge', '/pr-head' or '/branch'
            (optional, default true)
    """
    if data.get("notification-context", None):
        nc_trait = XML.SubElement(
            traits,
            "org.jenkinsci.plugins.githubScmTraitNotificationContext."
            "NotificationContextTrait",
        )
        nc = data.get("notification-context")
        nc_trait_label = XML.SubElement(nc_trait, "contextLabel")
        nc_trait_suffix = XML.SubElement(nc_trait, "typeSuffix")
        if isinstance(nc, str):
            nc_trait_label.text = nc
            nc_trait_suffix.text = "true"
        else:
            nc_trait_label.text = nc.get("label")
            nc_suffix = nc.get("suffix", None)
            if nc_suffix is None:
                nc_trait_suffix.text = "true"
            elif type(nc_suffix) == bool:
                nc_trait_suffix.text = str(nc_suffix).lower()
            else:
                nc_trait_suffix.text = nc_suffix


def add_github_checks_traits(traits, data):
    """Enable and configure the usage of GitHub Checks API

    Requires the :jenkins-plugins:`Github Checks <github-checks>` plugin.

    :arg dict status-checks:

        * **name** (str): The text of the context label for GitHub Checks entry
        * **skip** (bool): Skips publishing Checks (optional, default false)
        * **skip-branch-source-notifications** (bool): Disables the default
            option of publishing statuses through Status API
            (optional, default false)
        * **publish-unstable-as-neutral** (bool): Publishes UNSTABLE builds
            as neutral (not failed) checks
            (optional, default false)
        * **suppress-log-output** (bool): Suppresses sending build logs to GitHub
            (optional, default false)
        * **suppress-progress-updates** (bool): Suppresses updating build progress
            (optional, default false)
        * **verbose-logs** (bool): Enables sending build console logs to GitHub
            (optional, default false)
    """
    if data.get("status-checks", None):
        status_checks_section = data["status-checks"]
        if status_checks_section.get("verbose-logs", None):
            sct = XML.SubElement(
                traits,
                "io.jenkins.plugins.checks.github.config.GitHubSCMSourceChecksTrait",
                {"plugin": "github-checks"},
            )
            sct_mapping = [("verbose-logs", "verboseConsoleLog", "false")]
            helpers.convert_mapping_to_xml(
                sct, status_checks_section, sct_mapping, fail_required=True
            )

        status_check_trait = XML.SubElement(
            traits,
            "io.jenkins.plugins.checks.github.status.GitHubSCMSourceStatusChecksTrait",
            {"plugin": "github-checks"},
        )
        status_check_trait_mapping = [
            ("skip", "skip", "false"),
            ("skip-branch-source-notifications", "skipNotifications", "false"),
            ("publish-unstable-as-neutral", "unstableBuildNeutral", "false"),
            ("name", "name", "Jenkins"),
            ("suppress-log-output", "suppressLogs", "false"),
            ("suppress-progress-updates", "skipProgressUpdates", "false"),
        ]
        helpers.convert_mapping_to_xml(
            status_check_trait,
            status_checks_section,
            status_check_trait_mapping,
            fail_required=True,
        )
