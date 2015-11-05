# Cleanup Robot
# ${ROBOT_VENV} comes from the include-raw-integration-install-robotframework.sh
# script.
rm -rf ${ROBOT_VENV}

# Cleanup workspace.
# Leftover files from previous runs can be wrongly copied as results.
# TODO: Should this be a separate script/macro?
rm -rf .
