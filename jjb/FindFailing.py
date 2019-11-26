# !/usr/bin/env python
import sys
import os
import operator
import copy

# print(sys.argv[1])
if len(sys.argv) == 2:
    minNumberOfConsecutiveFailures = int(sys.argv[1])
else:
    minNumberOfConsecutiveFailures = int(os.environ['CONSECUTIVEFAILURES'])
print(minNumberOfConsecutiveFailures)
with open("numberOfBuilds") as f:
    line = f.read()
    number_found = False
    position_of_delimiting_space = 0
    for i in range(len(line)):
        if line[i] == " ":
            if not number_found:
                continue
            else:
                position_of_delimiting_space = i
                break
        else:
            number_found = True

numberOfBuilds = dict()
with open("numberOfBuilds") as f:
    for idx, j in enumerate(f):
        numberOfBuilds[j[1+position_of_delimiting_space:].replace('\n', '')] = \
            int(j[:position_of_delimiting_space])

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
                # unstable - if it is the need here can be collected similarly as failed
                continue
        else:
            # RED POINT
            if ((lastFailedBuild[key] > lastSuccessfulBuild[key]) and
                (lastFailedBuild[key] > lastStableBuild[key]) and
                (lastFailedBuild[key] > lastUnstableBuild[key])):
                # lastFailedBuild is the latest build
                cmp_with = max(
                        lastSuccessfulBuild[key],
                        lastStableBuild[key],
                        lastUnstableBuild[key])
                if cmp_with == -1:
                    cmp_with = 0
                if (lastFailedBuild[key] - cmp_with > minNumberOfConsecutiveFailures):
                    build[key] = lastFailedBuild[key] - cmp_with
                    # if key in numberOfBuilds:
                    #     if build[key] > numberOfBuilds[key]:
                    #         build[key]  =  numberOfBuilds[key]-1
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
    g.write("<a href = \"/job/" + i[0] + "\">" + i[0] + "</a>&nbsp;" + str(i[1]) + "<br/>")
g.close()
pass
