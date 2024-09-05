#!/usr/bin/env python
# Copyright (C) 2015 Wayne Warren
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

import abc
import fnmatch
import logging
import time

from jenkins_jobs.builder import JenkinsManager
from jenkins_jobs.registry import ModuleRegistry
from jenkins_jobs.roots import Roots
from jenkins_jobs.xml_config import XmlJobGenerator
from jenkins_jobs.xml_config import XmlViewGenerator
from jenkins_jobs.loader import load_files


logger = logging.getLogger(__name__)


def matches(name, glob_list):
    """
    Checks if the given string, ``name``, matches any of the glob patterns in
    the iterable, ``glob_list``

    :arg str name: String (job or view name) to test if it matches a pattern
    :arg iterable glob_list: glob patterns to match (list, tuple, set, etc.)
    """
    return any(fnmatch.fnmatch(name, glob) for glob in glob_list)


def filter_matching(item_list, glob_list):
    if not glob_list:
        return item_list
    return [item for item in item_list if matches(item.name, glob_list)]


class BaseSubCommand(metaclass=abc.ABCMeta):
    """Base class for Jenkins Job Builder subcommands, intended to allow
    subcommands to be loaded as stevedore extensions by third party users.
    """

    def __init__(self):
        pass

    @abc.abstractmethod
    def parse_args(self, subparsers, recursive_parser):
        """Define subcommand arguments.

        :param subparsers
          A sub parser object. Implementations of this method should
          create a new subcommand parser by calling
            parser = subparsers.add_parser('command-name', ...)
          This will return a new ArgumentParser object; all other arguments to
          this method will be passed to the argparse.ArgumentParser constructor
          for the returned object.
        """

    @abc.abstractmethod
    def execute(self, config):
        """Execute subcommand behavior.

        :param config
          JJBConfig object containing final configuration from config files,
          command line arguments, and environment variables.
        """

    @staticmethod
    def parse_option_recursive_exclude(parser):
        """Add '--recursive'  and '--exclude' arguments to given parser."""
        parser.add_argument(
            "-r",
            "--recursive",
            action="store_true",
            dest="recursive",
            default=False,
            help="look for yaml files recursively",
        )

        parser.add_argument(
            "-x",
            "--exclude",
            dest="exclude",
            action="append",
            default=[],
            help="paths to exclude when using recursive search, "
            "uses standard globbing.",
        )


class JobsSubCommand(BaseSubCommand):
    """Base class for Jenkins Job Builder subcommands which generates jobs."""

    def load_roots(self, jjb_config, path_list):
        roots = Roots(jjb_config)
        load_files(jjb_config, roots, path_list)
        return roots

    def make_jobs_and_views_xml(self, jjb_config, path_list, glob_list):
        logger.info("Updating jobs in {0} ({1})".format(path_list, glob_list))
        orig = time.time()

        roots = self.load_roots(jjb_config, path_list)

        builder = JenkinsManager(jjb_config)

        registry = ModuleRegistry(jjb_config, builder.plugins_list)
        registry.set_macros(roots.macros)

        jobs = filter_matching(roots.generate_jobs(), glob_list)
        views = filter_matching(roots.generate_views(), glob_list)

        registry.amend_job_dicts(jobs)

        xml_job_generator = XmlJobGenerator(registry)
        xml_view_generator = XmlViewGenerator(registry)

        xml_jobs = xml_job_generator.generateXML(jobs)
        xml_views = xml_view_generator.generateXML(views)

        step = time.time()
        logging.debug("%d XML files generated in %ss", len(jobs), str(step - orig))

        return builder, xml_jobs, xml_views
