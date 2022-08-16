#!/bin/sh

echo "Cleaning up Robot installation..."

# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# TODO: Is this still needed when we have integration-cleanup-workspace?
rm -rf "${ROBOT_VENV}"
