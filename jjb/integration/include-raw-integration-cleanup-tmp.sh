echo "Cleaning up the Robot installation..."

# Cleanup Robot
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
# TODO: Is this still needed when we have integration-cleanup-workspace?
rm -rf ${ROBOT_VENV}
