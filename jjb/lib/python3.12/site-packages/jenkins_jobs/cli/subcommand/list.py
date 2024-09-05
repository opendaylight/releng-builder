#!/usr/bin/env python
# Copyright (C) 2018 Sorin Sbarnea
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
import logging
import sys

from jenkins_jobs.builder import JenkinsManager
import jenkins_jobs.cli.subcommand.base as base
import jenkins_jobs.utils as utils


def list_duplicates(seq):
    seen = set()
    return set(x for x in seq if x in seen or seen.add(x))


class ListSubCommand(base.JobsSubCommand):
    def parse_args(self, subparser):
        list = subparser.add_parser("list", help="List jobs")

        self.parse_option_recursive_exclude(list)

        list.add_argument("names", help="name(s) of job(s)", nargs="*", default=None)
        list.add_argument(
            "-p", "--path", default=None, help="path to YAML file or directory"
        )

    def execute(self, options, jjb_config):
        jobs = self.get_jobs(jjb_config, options.path, options.names)

        logging.info("Matching jobs: %d", len(jobs))
        stdout = utils.wrap_stream(sys.stdout)

        for job in jobs:
            stdout.write((job + "\n").encode("utf-8"))

    def get_jobs(self, jjb_config, path_list, glob_list):
        if path_list:
            roots = self.load_roots(jjb_config, path_list)
            jobs = base.filter_matching(roots.generate_jobs(), glob_list)
            job_names = [j.name for j in jobs]
        else:
            jenkins = JenkinsManager(jjb_config)
            job_names = [
                j["fullname"]
                for j in jenkins.get_jobs()
                if not glob_list or base.matches(j["fullname"], glob_list)
            ]

        job_names = sorted(job_names)
        for duplicate in list_duplicates(job_names):
            logging.warning("Found duplicate job name '%s', likely bug.", duplicate)

        logging.debug("Builder.get_jobs: returning %r", job_names)

        return job_names
