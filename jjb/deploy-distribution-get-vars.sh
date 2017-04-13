#!/bin/bash
set -xeu -o pipefail

export BUNDLE
export BUNDLE_URL
export BUNDLE_VERSION

BUNDLE_VERSION=$(xpath "${BUNDLE_POM}" '/project/version/text()' 2> /dev/null)
BUNDLE="distribution-karaf-${BUNDLE_VERSION}.zip"
BUNDLE_URL="/tmp/r/org/opendaylight/integration/distribution-karaf/${BUNDLE_VERSION}/${BUNDLE}"

# Used to inject BUNDLE_ variables back into Jenkins
env | grep BUNDLE_ | sort | tee deploy-distribution.env
