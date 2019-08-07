#!/bin/bash
#@IgnoreInspection BashAddShebang
# Activate robotframework virtualenv
# ${ROBOT_VENV} comes from the integration-install-robotframework.sh
# script.
# shellcheck disable=SC1090,SC1091
source "${ROBOT_VENV}/bin/activate"
source /tmp/common-functions.sh "${BUNDLEFOLDER}"

echo "#################################################"
echo "##         Configure Cluster and Start         ##"
echo "#################################################"

get_features

# shellcheck disable=SC2034
nodes_list=$(get_nodes_list)

run_plan "script"

create_configuration_script

create_startup_script

copy_and_run_configuration_script

run_plan "config"

copy_and_run_startup_script

# vim: ts=4 sw=4 sts=4 et ft=sh :
