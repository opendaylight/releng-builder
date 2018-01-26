#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

echo "Waiting for ODL REST API to come up..."
COUNT="0"
while true; do
    # Will fail if 8181 isn't open, check for that first
    RESP=$( curl --user admin:admin --silent --head --output /dev/null --write-out '%{http_code}' http://localhost:8181/restconf/modules )
    echo "Curl of ODL REST API HTTP response code: $RESP"
    if [[ $RESP = *200* ]]; then
        echo "ODL REST API returned 200"
        break
    elif [ $COUNT -gt 120 ]; then
        echo "Timeout waiting for HTTP 200 from REST API"
        exit 1
    else
        ((COUNT+=1))
        sleep 1
    fi
done
