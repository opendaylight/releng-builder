#!/usr/bin/python

import argparse
import copy
import os
import ruamel.yaml

def create_and_update_project_jobs(release_on_stable_branch, release_on_master_branch, job_dir):
    """Creates and updates project build jobs for the current and next dev release.

    Project jobs are jobs defined in the project.yaml that have the same name
    the directory they are in.

    Only updates projects where the top project configuration has a name that
    is equivalent to the current release. For example project name
    "aaa-silicon" would have a release that matches what was passed to
    release_on_stable_branch.
    """

    for directory in filter(lambda x: os.path.isdir(os.path.join(job_dir, x)), os.listdir(job_dir)):
        try:
            with open(os.path.join(job_dir, directory, "{}.yaml".format(directory)), 'r') as f:
                data = ruamel.yaml.round_trip_load(f)

                # Only create new jobs if the top level project name matches release_on_stable_branch variable
                if not data[0]['project']['name'] == "{}-{}".format(directory, release_on_stable_branch.lower()):
                    continue

                # Create a new job for the next release on the master branch
                new_job = copy.deepcopy(data[0])
                new_job['project']['name'] = '{}-{}'.format(directory, release_on_master_branch.lower())
                new_job['project']['branch'] = 'master'
                new_job['project']['stream'] = '{}'.format(release_on_master_branch.lower())

                # Update exiting job for the new stable branch
                data[0]['project']['branch'] = "stable/{}".format(release_on_stable_branch.lower())

                data.insert(0, new_job)

            with open(os.path.join(job_dir, directory, "{}.yaml".format(directory)), 'w') as f:
                stream = ruamel.yaml.round_trip_dump(data)
                f.write('---\n')
                f.write(stream)
        except FileNotFoundError:  # If project.yaml file does not exist we can skip
            pass

parser = argparse.ArgumentParser(
    description="""Creates & updates jobs for ODL projects when branch cutting.

    Example usage: python scripts/cut-branch.sh Silicon Phosphorus jjb/
    """
)
parser.add_argument(
    'release_on_stable_branch', metavar='RELEASE_ON_STABLE_BRANCH', type=str,
    help='The ODL release codename for the stable branch that was cut.',
)
parser.add_argument(
    'release_on_master_branch', metavar='RELEASE_ON_MASTER_BRANCH', type=str,
    help='The ODL release codename for the new master branch (eg. Magnesium, Aluminium, Silicon).',
)
parser.add_argument(
    'job_dir', metavar='JOB_DIR', type=str,
    help='Path to the directory containing JJB config.',
)
args = parser.parse_args()

create_and_update_project_jobs(args.release_on_stable_branch, args.release_on_master_branch, args.job_dir)
