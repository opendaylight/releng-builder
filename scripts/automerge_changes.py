#!/usr/bin/env python
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2022 The Linux Foundation.  All rights reserved.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License v1.0 which accompanies this distribution,
# and is available at http://www.eclipse.org/legal/epl-v10.html
##############################################################################

""" The python script automates a part of release workflow used for merging
patches during version bumping process for a new release.

The script also takes the input file `merge-order.log`. The list of changes are
obtained from a topic and a merge is initiated when the parent project
has been merged successfully, determined while listening on stream-events.

The output is list of changes successfully merged.

The script requires 'pygerrit' module installed within the virtualenv.

usage: automerge_changes.py [-h] [-g HOSTNAME] [-p PORT] [-u USERNAME] [-b]
                           [-t SECONDS] [-v] [-i] [-f MERGELOG] [-to TOPIC]
                           [-br BRANCH] [-o OWNER]

Ref: https://review.openstack.org/Documentation/cmd-set-reviewers.html

Usage:

virtualenv ~/.virtualenvs/testpy
source ~/.virtualenvs/testpy/bin/activate
pip install --upgrade pygerrit
python merge_changes_in_topic.py -u askb -o jenkins-releng@opendaylight.org -to Oxygen-SR3 -br stable/oxygen
deactivate
"""

# TODO
# 1. Improve documentation/usage
# 2. Determine how to filter the stream-events on given topic
# 3. Move to Pygerrit2

import argparse
import logging
import sys
from threading import Event
import time
import json

from pygerrit.ssh import GerritSSHCommandResult
from pygerrit.ssh import GerritSSHClient
from pygerrit.client import GerritClient
from pygerrit.error import GerritError
from pygerrit.events import ErrorEvent
from pygerrit.events import *
from requests.exceptions import RequestException


def get_merge_order_list(filename='merge-order.log'):
    return open(filename).read().splitlines()


def gerrit_cmd(client, cmd):
    try:
        return client.run_gerrit_command(cmd)
    except Exception as e:
        print 'Error when running gerrit command:', e


def get_mergejob_status(comment):
    regex = r"^(.+?):\n\n(.+?) \n\n(.+?): (.+?)\n\n(.*)"
    matches = re.finditer(regex, comment)
    flag = True
    for matchNum, match in enumerate(matches):
        matchNum = matchNum + 1
        for groupNum in range(0, len(match.groups())):
            groupNum = groupNum + 1
            if groupNum == 2 or groupNum == 4:
                if match.group(2) != "Build Successful":
                    flag &= False
                if match.group(4) != "SUCCESS (skipped)":
                    flag &= False
    return flag


def get_next_change(jdata, next):
    for j in jdata:
        if j['project'] == next:
            return j
    return None


def _main():
    descr = 'Merge changes using Gerrit SSH client and stream-events'
    parser = argparse.ArgumentParser(
        description=descr,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-g', '--gerrit-hostname', dest='hostname',
                        default='git.opendaylight.org',
                        help='gerrit server hostname')
    parser.add_argument('-p', '--port', dest='port',
                        type=int, default=29418,
                        help='port number')
    parser.add_argument('-u', '--username', dest='username',
                        help='username')
    parser.add_argument('-b', '--blocking', dest='blocking',
                        action='store_true',
                        help='block on event get')
    parser.add_argument('-t', '--timeout', dest='timeout',
                        default=None, type=int,
                        metavar='SECONDS',
                        help='timeout for blocking event get')
    parser.add_argument('-v', '--verbose', dest='verbose',
                        action='store_true',
                        help='enable verbose (debug) logging')
    parser.add_argument('-i', '--ignore-stream-errors', dest='ignore',
                        action='store_true',
                        help='do not exit when an error event is received')
    parser.add_argument('-f', '--merge-order-log', dest='mergelog',
                        default='merge-order104.log',
                        help='path to merge-order.log')
    parser.add_argument('-to', '--topic', dest='topic',
                        help='use topic')
    parser.add_argument('-br', '--branch', dest='branch',
                        help='use branch')
    parser.add_argument('-o', '--owner', dest='owner', default='self',
                        help='use owner')

    #import pdb; pdb.set_trace()

    options = parser.parse_args()
    if options.timeout and not options.blocking:
        parser.error('Can only use --timeout with --blocking')

    level = logging.DEBUG if options.verbose else logging.INFO
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s',
                        level=level)

    # get the project list from the file
    # plist = get_merge_order_list(filename=options.mergelog)

    # setup connection to stream-events
    try:
        gerrit = GerritClient(host=options.hostname,
                              username=options.username,
                              port=options.port,
                              keepalive=60)

        client = GerritSSHClient(hostname=options.hostname,
                              username=options.username,
                              port=options.port,
                              keepalive=60)
        logging.info("Connected to Gerrit version [%s]",
                     gerrit.gerrit_version())
        logging.info("Connected to Gerrit stream version [%s]",
                     client.get_remote_version())
        gerrit.start_event_stream()
    except GerritError as err:
        logging.error("Gerrit error: %s", err)
        return 1

    # get the list of patches from a topic
    try:
        query = ["status:open"]
        if options.topic:
            query += ["topic:" + options.topic]
        if options.branch:
            query += ["branch:" + options.branch]
        if options.owner:
            query += ["owner:" + options.owner]
        # query += ["limit:" + str(len(plist) + 2)]
        cmd = ["query --format=JSON --current-patch-set"]
        cmd += query
        logging.info("gerrit review query %s", query)
        changes = gerrit_cmd(client, " ".join(cmd))
        data = changes.stdout.readlines()[:-1]
        jdata = [json.loads(d) for d in data]
        logging.info("%s has %d changes to merge", options.topic, len(jdata))
        for j in jdata:
            logging.info("project: %s commit: %s", j['project'],
                           j["currentPatchSet"]["revision"])
            cmd = ["set-reviewers -r jenkins-releng@opendaylight.org"]
            cmd += [j['currentPatchSet']['revision']]
            retval = gerrit_cmd(client, " ".join(cmd))
            cmd = ["review --verified +1 --code-review +2 -s"]
            cmd += [j['currentPatchSet']['revision']]
            retval = gerrit_cmd(client, " ".join(cmd))
            logging.info("merged: [%s], project: %s commit: %s", j, j['project'],
                           j["currentPatchSet"]["revision"])
    except RequestException as err:
        logging.error("Error: %s", str(err))
    finally:
        logging.debug("Stopping event stream...")
        gerrit.stop_event_stream()
        client.close()


    # # initate a merge starting from 'odlparent'
    # # get project merge status before initiating the merge for each project
    # # p = plist.pop(0)
    # inprogress = get_next_change(jdata, p)
    # logging.debug("inprogress: [%s]",
    #              inprogress)
    # if inprogress is None:
    #     logging.info("No change for project: [%s] available", p)
    #     return 1
    #
    # if inprogress['project'] == 'odlparent':
    #         cmd = ["review --verified +1 --code-review +2 -s"]
    #         cmd += [inprogress['currentPatchSet']['revision']]
    #         retval = gerrit_cmd(client, " ".join(cmd))
    #         logging.info("Started merge: [%s]",
    #                      inprogress)

    # # Listen to events
    # errors = Event()
    # try:
    #     while True:
    #         # listen to all events, branch, project
    #         event = gerrit.get_event(block=options.blocking,
    #                                  timeout=options.timeout)
    #         if event:
    #             logging.info("Event: %s", event)
    #             logging.debug("Event: %s", event.json)
    #             # start a new patch if the merge was successful
    #             if isinstance(event, ChangeMergedEvent) and \
    #                 event.json['change']['project'] == \
    #                 inprogress['project'] and \
    #                 event.json['change']['topic'] == topic and \
    #                 event.json['patchSet']['revision'] == \
    #                 inprogress['currentPatchSet']['revision'] and \
    #                     get_mergejob_status(event.json['comment']) is True:
    #                 # start a new patch
    #                 logging.info("Merge sucessful: [%s]",
    #                              inprogress['change']['project'])
    #                 inprogress = get_next_change(jdata, plist.pop(0))
    #                 if inprogress is not None:
    #                     cmd = ["review --verified +1 --code-review +2 -s"]
    #                     cmd += [inprogress['currentPatchSet']['revision']]
    #                     retval = gerrit_cmd(client, " ".join(cmd))
    #                     # check for errors or add exception
    #                     logging.info("Started merge: [%s]",
    #                                  inprogress['change']['project'])
    #
    #             # re-initiate the merge, if the merge failed
    #             if isinstance(event, MergeFailedEvent) and \
    #                 event['change']['project'] == \
    #                 inprogress['project'] and \
    #                 event['change']['topic'] == topic and \
    #                 event.json['patchSet']['revision'] == \
    #                 inprogress['currentPatchSet']['revision'] and \
    #                     get_mergejob_status(event.json['comment']) is False:
    #                 cmd = ["review -m remerge"]
    #                 cmd += [inprogress['currentPatchSet']['revision']]
    #                 retval = gerrit_cmd(client, " ".join(cmd))
    #                 # check for errors or add exception
    #                 logging.info("Merge Failed: [%s], re-initiated merge",
    #                              inprogress['change']['project'])
    #
    #             # handle other errors
    #             if isinstance(event, ErrorEvent) and not options.ignore:
    #                 logging.error(event.error)
    #                 errors.set()
    #                 break
    #         else:
    #             logging.debug("No event")
    #             if not options.blocking:
    #                 time.sleep(1)
    # except KeyboardInterrupt:
    #     logging.info("Terminated by user")
    # finally:
    #     logging.debug("Stopping event stream...")
    #     gerrit.stop_event_stream()
    #     client.close()

    # if errors.isSet():
    #    logging.error("Exited with error")
    #    return 1

if __name__ == "__main__":
    sys.exit(_main())
