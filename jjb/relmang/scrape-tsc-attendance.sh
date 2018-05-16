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
  curl --silent \
    https://meetings.opendaylight.org/opendaylight-meeting/$year/tsc/ | \
    grep -P -o 'openday.*?log.txt' | \
    while read log_filename;
    do
      echo $log_filename
      # If meeting is between start-end dates
      meeting_date=$(echo $log_filename | grep -o -P "$year-\d\d-\d\d")
      echo $meeting_date
      if [[ "$meeting_date" > "$START_DATE" ||
            "$meeting_date" = "$START_DATE" ]] &&
         [[ "$meeting_date" < "$END_DATE" ||
            "$meeting_date" = "$END_DATE" ]]; then
        echo "This date is good"
        meeting_log=$(curl --silent \
          https://meetings.opendaylight.org/opendaylight-meeting/$year/tsc/$log_filename)
        echo $meeting_log | grep -o '#project' || true
      fi
    done
  # TODO: Iterate over list of meeting logs, curling down each between start-end

  # TODO: Iterate over Managed Projects, grep for entries, mark absent/present
done

