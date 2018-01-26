#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

curl -i -u "admin:admin" http://localhost:8181/restconf/streams

# TODO Make sure returns 200
# TODO Make sure returns {"streams":{}}
