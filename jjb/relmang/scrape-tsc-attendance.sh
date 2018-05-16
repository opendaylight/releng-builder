#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# TODO: List of Managed Projects

# Extract years from START_DATE and END_DATE
echo $START_DATE
echo $END_DATE
start_year="$(cut -d'-' -f1 <<<"$START_DATE")"
end_year="$(cut -d'-' -f1 <<<"$END_DATE")"
echo $start_year
echo $end_year

# Iterate over minutes dirs for every year between start and end dates
for year in $(seq $start_year $end_year); do
  echo $year
  # TODO: Curl down HTML list of meeting logs
  curl https://meetings.opendaylight.org/opendaylight-meeting/2018/tsc/ | log.txt
  # TODO: Iterate over list of meeting logs, curling down each between start-end

  # TODO: Iterate over Managed Projects, grep for entries, mark absent/present
done

