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

import logging
import sys

from jenkins_jobs.errors import JenkinsJobsException
import jenkins_jobs.cli.subcommand.base as base


logger = logging.getLogger(__name__)


class UpdateSubCommand(base.JobsSubCommand):
    def parse_arg_path(self, parser):
        parser.add_argument(
            "path",
            nargs="?",
            default=sys.stdin,
            help="colon-separated list of paths to YAML files " "or directories",
        )

    def parse_arg_names(self, parser):
        parser.add_argument("names", help="name(s) of job(s)", nargs="*")

    def parse_args(self, subparser):
        update = subparser.add_parser("update")

        self.parse_option_recursive_exclude(update)

        self.parse_arg_path(update)
        self.parse_arg_names(update)

        update.add_argument(
            "--delete-old",
            action="store_true",
            dest="delete_old",
            default=False,
            help="delete obsolete jobs",
        )
        update.add_argument(
            "-p",
            "--plugin-info",
            dest="plugins_info_path",
            default=None,
            help="path to plugin info YAML file. Can be used to provide "
            "previously retrieved plugins info when connecting credentials "
            "don't have permissions to query.",
        )
        update.add_argument(
            "--workers",
            type=int,
            default=1,
            dest="n_workers",
            help="number of workers to use, 0 for autodetection and 1 "
            "for just one worker.",
        )
        update.add_argument(
            "--existing-only",
            action="store_true",
            default=False,
            dest="existing_only",
            help="update existing jobs only",
        )

        update.add_argument(
            "--enabled-only",
            action="store_true",
            default=False,
            dest="enabled_only",
            help="update enabled jobs only",
        )

        update_type = update.add_mutually_exclusive_group()
        update_type.add_argument(
            "-j",
            "--jobs-only",
            action="store_const",
            dest="update",
            const="jobs",
            help="update only jobs",
        )
        update_type.add_argument(
            "-v",
            "--views-only",
            action="store_const",
            dest="update",
            const="views",
            help="update only views",
        )

    def execute(self, options, jjb_config):
        if options.n_workers < 0:
            raise JenkinsJobsException(
                "Number of workers must be equal or greater than 0"
            )

        builder, xml_jobs, xml_views = self.make_jobs_and_views_xml(
            jjb_config, options.path, options.names
        )

        if options.enabled_only:
            # filter out jobs which are disabled
            xml_jobs_filtered = []
            for xml_job in xml_jobs:
                el = xml_job.xml.find("./disabled")
                if el is not None:
                    if el.text == "true":
                        continue
                xml_jobs_filtered.append(xml_job)

            logging.info(
                "Will only deploy enabled jobs "
                "(skipping {} disabled jobs)".format(
                    len(xml_jobs) - len(xml_jobs_filtered)
                )
            )
            xml_jobs = xml_jobs_filtered

        if options.update in {"jobs", "all"}:
            jobs, num_updated_jobs = builder.update_jobs(
                xml_jobs,
                n_workers=options.n_workers,
                existing_only=options.existing_only,
            )
            logger.info("Number of jobs updated: %d", num_updated_jobs)
        if options.update in {"views", "all"}:
            views, num_updated_views = builder.update_views(
                xml_views,
                n_workers=options.n_workers,
                existing_only=options.existing_only,
            )
            logger.info("Number of views updated: %d", num_updated_views)

        if options.delete_old:
            if options.update in {"jobs", "all"}:
                keep_jobs = [job.name for job in xml_jobs]
                n = builder.delete_old_managed_jobs(keep=keep_jobs)
                logger.info("Number of jobs deleted: %d", n)
            if options.update in {"views", "all"}:
                keep_views = [view.name for view in xml_views]
                n = builder.delete_old_managed_views(keep=keep_views)
                logger.info("Number of views deleted: %d", n)
