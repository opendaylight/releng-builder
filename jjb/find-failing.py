#!/usr/bin/env python
# flake8: noqa
# reason for ignoring flake8 for all file:
# - this version was checked by flake8
# - F401 'copy' imported but unused
# - F821 undefined name 'nextBuildNumber'
# - warnings are connected with use of the "exec" function
#   which produce copies of dict structure to those missing variables

import sys
import os
import operator
import copy  # noqa: F401

if len(sys.argv) == 2:
    minNumOfConsecFailures = int(sys.argv[1])
else:
    minNumOfConsecFailures = int(os.environ['CONSECUTIVEFAILURES'])

jobs_statistics = ['lastFailedBuild',
                   'lastSuccessfulBuild',
                   'lastUnsuccessfulBuild',
                   'lastStableBuild',
                   'lastUnstableBuild',
                   'nextBuildNumber']
for idx, j in enumerate(jobs_statistics):
    build = dict()
    with open(j) as f:
        for idx, i in enumerate(f):
            if (idx % 2) == 0:
                buildNumber = int(i.replace('\n', ''))
            if (idx % 2) != 0:
                job = os.path.basename(i.replace('\n', ''))
                build[job] = buildNumber
    exec(j + "  =  copy.deepcopy(build)")

build = dict()
print("% 6s, % 6s, % 6s, % 6s, % 6s, % 6s" % (
    'NextB',
    'FailB',
    'UnsucB',
    'SuccB',
    'UnstB',
    'StablB'))
for key in nextBuildNumber:
    if key not in nextBuildNumber:
        nextBuildNumber[key] = -1
    if key not in lastFailedBuild:
        lastFailedBuild[key] = -1
    if key not in lastUnsuccessfulBuild:
        lastUnsuccessfulBuild[key] = -1
    if key not in lastSuccessfulBuild:
        lastSuccessfulBuild[key] = -1
    if key not in lastUnstableBuild:
        lastUnstableBuild[key] = -1
    if key not in lastStableBuild:
        lastStableBuild[key] = -1
    print("% 6d,% 6d,% 6d,% 6d,% 6d,% 6d, % s" % (
        nextBuildNumber[key],
        lastFailedBuild[key],
        lastUnsuccessfulBuild[key],
        lastSuccessfulBuild[key],
        lastUnstableBuild[key],
        lastStableBuild[key],
        key))
    if nextBuildNumber[key] == 1:
        continue
    else:
        if lastFailedBuild[key] == -1:
            if lastUnstableBuild[key] == -1:
                continue
            else:
                # unstable - could be collected similarly as failed
                continue
        else:
            # RED POINT
            if ((lastFailedBuild[key] > lastSuccessfulBuild[key]) and
                    (lastFailedBuild[key] > lastStableBuild[key]) and
                    (lastFailedBuild[key] > lastUnstableBuild[key])):
                cmp_with = max(
                        lastSuccessfulBuild[key],
                        lastStableBuild[key],
                        lastUnstableBuild[key])
                if cmp_with == -1:
                    cmp_with = 0
                if (lastFailedBuild[key] - cmp_with > minNumOfConsecFailures):
                    build[key] = lastFailedBuild[key] - cmp_with
            else:
                continue

sorted_x = sorted(build.items(), key=operator.itemgetter(1), reverse=True)
print("######################")
for i in sorted_x:
    print(i)

try:
    os.remove("JobsWithMoreConsecutiveFailures.html")
except OSError:
    pass

g = open("JobsWithMoreConsecutiveFailures.html", "a")
for i in sorted_x:
    g.write("<a href=\"/job/" +
            i[0] +
            "\">" +
            i[0] +
            "</a>&nbsp;" +
            str(i[1]) +
            "<br/>")
g.close()
pass
