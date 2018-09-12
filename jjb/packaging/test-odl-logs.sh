#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Execute the test ODL logs playbook
sudo ansible-playbook -i "localhost," -c local $WORKSPACE/ansible/tests/test-odl-logs.yaml -v
