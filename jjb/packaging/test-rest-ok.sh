#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

echo "Waiting for controller to come up..."
COUNT="0"
while true; do
    set +e
    RESP=$( curl --user admin:admin --silent --head --output /dev/null --write-out '%{http_code}' http://localhost:8181/restconf/modules )
    echo $?
    set -e
    echo $RESP
    if [[ $RESP = *200* ]]; then
        echo "Controller is up"
        break
    elif [ $COUNT -gt 600 ]; then
        echo "Timeout waiting for controller"
        exit 1
    else
        ((COUNT+=1))
        sleep 1
    fi
done
