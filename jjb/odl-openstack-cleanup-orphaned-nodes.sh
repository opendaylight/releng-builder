#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 - 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> Cleanup orphaned servers"

minion_in_jenkins() {
    # Usage: check_stack_in_jenkins STACK_NAME JENKINS_URL [JENKINS_URL...]
    # Returns: 0 If stack is in Jenkins and 1 if stack is not in Jenkins.

    MINION="${1}"

    minions=()
    for jenkins in "${@:2}"; do
        JENKINS_URL="$jenkins/computer/api/json?tree=computer[displayName]"
        resp=$(curl -s -w "\\n\\n%{http_code}" --globoff -H "Content-Type:application/json" "$JENKINS_URL")
        json_data=$(echo "$resp" | head -n1)
        #status=$(echo "$resp" | awk 'END {print $NF}')

        # We purposely want to wordsplit here to combine the arrays
        # shellcheck disable=SC2206,SC2207
        minions=(${minions[@]} $(echo "$json_data" | \
            jq -r '.computer[].displayName' | grep -v master)
        )
    done

    if [[ "${minions[*]}" =~ $MINION ]]; then
        return 0
    fi

    return 1
}

##########################
## FETCH ACTIVE MINIONS ##
##########################
# Fetch server list before fetching active minions to minimize race condition
# where we might be trying to delete servers while jobs are trying to start

# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"

# We purposely need word splitting here to create the OS_SERVERS array.
# shellcheck disable=SC2207
mapfile -t OS_SERVERS < <(openstack server list -f value -c "Name" | grep -E 'prd|snd')

deactivate

#############################
## DELETE ORPHANED SERVERS ##
#############################

# shellcheck source=/tmp/v/lftools/bin/activate disable=SC1091
source "/tmp/v/lftools/bin/activate"

# Search for servers that are not in use by either releng or sandbox silos and
# delete them.
for server in "${OS_SERVERS[@]}"; do
    # JENKINS_URLS is provided by the Jenkins Job declaration and intentially
    # needs to be globbed.
    # shellcheck disable=SC2153,SC2086
    if minion_in_jenkins "$server" $JENKINS_URLS; then
        # No need to delete server if it is still attached to Jenkins
        continue
    else
        echo "Deleting $server"
        lftools openstack --os-cloud opendaylight \
            server remove --minutes 15 "$server"
    fi
done

deactivate
