#!/bin/bash

# Options:
#   -x: Echo commands
#   -e: Fail on errors
#   -o pipefail: Fail on errors in scripts this calls, give stacktrace
set -ex -o pipefail

# Install required packages


cd $WORKSPACE/packaging/puppet/puppet-opendaylight

# Executes spec test
bundle exec rake spec
