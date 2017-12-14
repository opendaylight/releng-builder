#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2017 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> Cleanup orphaned servers"

virtualenv "/tmp/v/openstack"
# shellcheck source=/tmp/v/openstack/bin/activate disable=SC1091
source "/tmp/v/openstack/bin/activate"
pip install --upgrade pip
pip install --upgrade python-openstackclient python-heatclient
pip install --upgrade pipdeptree
pipdeptree

##########################
## FETCH ACTIVE MINIONS ##
##########################
# Fetch server list before fetching active minions to minimize race condition
# where we might be try to delete servers while jobs are trying to start
OS_SERVERS=($(openstack server list -f value -c "Name" | grep -E 'prd|snd'))

# Make sure we fetch active minions on both the releng and sandbox silos
ACTIVE_MINIONS=()
for silo in releng sandbox; do
    query="https://jenkins.opendaylight.org/$silo/computer/api/json?tree=computer[displayName]"
    resp=$(curl -s -w "\n\n%{http_code}" --header "Accept: application/json" "$query")
    json_data=$(echo "$resp" | head -n1)
    ACTIVE_MINIONS=(${ACTIVE_MINIONS[@]} $( echo "$json_data" \
        | jq -r '.computer[].displayName' | grep -v master))
done

#############################
## DELETE ORPHANED SERVERS ##
#############################
# Search for servers that are not in use by either releng or sandbox silos and
# delete them.
for server in "${OS_SERVERS[@]}"; do
    if [[ "${ACTIVE_MINIONS[*]}" =~ $server ]]; then
        # No need to delete server if it is still attached to Jenkins
        continue
    else
        echo "Deleting $server"
        openstack server delete "$server"
    fi
done
