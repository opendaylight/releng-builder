#!/bin/bash
# shellcheck disable=SC2016
echo "Wait please - searching for information about jobs..."
echo "            - searching for nextBuildNumber..."
find "$JENKINS_HOME"/jobs -type f -name "nextBuildNumber" -print0 | xargs -0 sh -c 'for arg do cat "$arg"; dirname "$arg"; done' > nextBuildNumber
echo "            - searching for lastUnsuccessfulBuild..."
find "$JENKINS_HOME"/jobs -type l -name "lastUnsuccessfulBuild" -print0 | xargs -0 sh -c 'for arg do /bin/ls -al "$arg" | rev | cut -d">" -f1 | rev ; dirname "$(dirname "$arg")" ; done' > lastUnsuccessfulBuild
echo "            - searching for lastSuccessfulBuild..."
find "$JENKINS_HOME"/jobs -type l -name "lastSuccessfulBuild" -print0 | xargs -0 sh -c 'for arg do /bin/ls -al "$arg" | rev | cut -d">" -f1 | rev ; dirname "$(dirname "$arg")" ; done' > lastSuccessfulBuild
echo "            - searching for lastStableBuild..."
find "$JENKINS_HOME"/jobs -type l -name "lastStableBuild" -print0 | xargs -0 sh -c 'for arg do /bin/ls -al "$arg" | rev | cut -d">" -f1 | rev ; dirname "$(dirname "$arg")" ; done' > lastStableBuild
echo "            - searching for lastUnstableBuild..."
find "$JENKINS_HOME"/jobs -type l -name "lastUnstableBuild" -print0 | xargs -0 sh -c 'for arg do /bin/ls -al "$arg" | rev | cut -d">" -f1 | rev ; dirname "$(dirname "$arg")" ; done' > lastUnstableBuild
echo "            - searching for lastFailedBuild..."
find "$JENKINS_HOME"/jobs -type l -name "lastFailedBuild" -print0 | xargs -0 sh -c 'for arg do /bin/ls -al "$arg" | rev | cut -d">" -f1 | rev ; dirname "$(dirname "$arg")" ; done' > lastFailedBuild
echo "            - searching for number of builds for every job..."
find "$JENKINS_HOME"/jobs/ -maxdepth 3 -mindepth 3 -type d | cut -d"/" -f5 | uniq -c > numberOfBuilds

# CONSECUTIVEFAILURES=${1-10}
# echo "Find jobs with last $CONSECUTIVEFAILURES consecutive failures ..."
# python FindFailing.py $CONSECUTIVEFAILURES
