#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# TODO: List of Managed Projects

# TODO: Extract years from START_DATE and END_DATE

# TODO: Iterate over minutes dirs for every year between start and end dates

# TODO: Curl down HTML list of meeting logs

# TODO: Iterate over list of meeting logs, curling down each between start-end

# TODO: Iterate over Managed Projects, grep for entries, mark absent/present
