#!/bin/bash

# NOTE: This file takes two jobs from the OpenStack infra and
#       puts them here. See here:
#
# https://github.com/openstack-infra/project-config/blob/master/jenkins/jobs/networking-odl.yaml

# This is the job which checks out devstack-gate
if [[ ! -e devstack-gate ]]; then
    git clone git://git.openstack.org/openstack-infra/devstack-gate
else
    cd devstack-gate
    git remote set-url origin git://git.openstack.org/openstack-infra/devstack-gate
    git remote update
    git reset --hard
    if ! git clean -x -f ; then
        sleep 1
        git clean -x -f
    fi
    git checkout master
    git reset --hard remotes/origin/master
    if ! git clean -x -f ; then
        sleep 1
        git clean -x -f
    fi
cd ..

# And this runs devstack-gate
export PYTHONUNBUFFERED=true
export DEVSTACK_GATE_TIMEOUT=120
export DEVSTACK_GATE_NEUTRON=1
# Uncomment the below to run the Tempest tests
#export DEVSTACK_GATE_TEMPEST=1
export BRANCH_OVERRIDE={branch-override}
if [ "$BRANCH_OVERRIDE" != "default" ] ; then
    export OVERRIDE_ZUUL_BRANCH=$BRANCH_OVERRIDE
fi
# Because we are testing a non standard project, add
# our project repository. This makes zuul do the right
# reference magic for testing changes.
export PROJECTS="stackforge/networking-odl $PROJECTS"
# Note the actual url here is somewhat irrelevant because it
# caches in nodepool, however make it a valid url for
# documentation purposes.
export DEVSTACK_LOCAL_CONFIG="enable_plugin networking-odl git://git.openstack.org/stackforge/networking-odl"

# Keep localrc to be able to set some vars in pre_test_hook
export KEEP_LOCALRC=1

cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
./safe-devstack-vm-gate-wrap.sh


# NOTE: I need review of the below
# I need publishers which capture logs like this:
#
#- publisher:
#    name: console-log
#    publishers:
#      - scp:
#          site: 'static.openstack.org'
#          files:
#            - target: 'logs/$LOG_PATH'
#              copy-console: true
#              copy-after-failure: true
#
#- publisher:
#    name: devstack-logs
#    publishers:
#      - scp:
#          site: 'static.openstack.org'
#          files:
#            - target: 'logs/$LOG_PATH'
#              source: 'logs/**'
#              keep-hierarchy: true
#              copy-after-failure: true

