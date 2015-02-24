#!/bin/bash

# NOTE: This file takes two jobs from the OpenStack infra and
#       puts them here. See here:
#
# https://github.com/openstack-infra/project-config/blob/master/jenkins/jobs/networking-odl.yaml

# *SIGH*. This is required to get lsb_release
sudo yum -y install redhat-lsb-core indent

# Need /opt/stack to be there
sudo mkdir -p /opt/stack
sudo chmod 777 /opt/stack

# Save existing WORKSPACE
SAVED_WORKSPACE=$WORKSPACE
export WORKSPACE=~/workspace
mkdir -p $WORKSPACE
cd $WORKSPACE

# This is the job which checks out devstack-gate
if [[ ! -e devstack-gate ]]; then
    echo "Cloning devstack-gate"
    git clone https://git.openstack.org/openstack-infra/devstack-gate
else
    echo "Fixing devstack-gate git remotes"
    cd devstack-gate
    git remote set-url origin https://git.openstack.org/openstack-infra/devstack-gate
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
fi

# Set the pieces we want to test
if [ "$GERRIT_PROJECT" == "openstack/neutron" ]; then
    ZUUL_PROJECT=$GERRIT_PROJECT
    ZUUL_BRANCH=$GERRIT_REFSPEC
elif [ "$GERRIT_PROJECT" == "openstack-dev/devstack" ]; then
    ZUUL_PROJECT=$GERRIT_PROJECT
    ZUUL_BRANCH=$GERRIT_REFSPEC
fi

echo "Setting environment variables"
# And this runs devstack-gate
export PYTHONUNBUFFERED=true
export DEVSTACK_GATE_TIMEOUT=120
export DEVSTACK_GATE_NEUTRON=1
# Uncomment the below to run the Tempest tests
#export DEVSTACK_GATE_TEMPEST=1
export BRANCH_OVERRIDE=master
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
if [ "$GERRIT_PROJECT" == "stackforge/networking-odl" ]; then
    export DEVSTACK_LOCAL_CONFIG="enable_plugin networking-odl https://$GERRIT_HOST/$GERRIT_PROJECT $GERRIT_REFSPEC"
else
    export DEVSTACK_LOCAL_CONFIG="enable_plugin networking-odl https://git.openstack.org/stackforge/networking-odl"
fi


# Keep localrc to be able to set some vars in pre_test_hook
export KEEP_LOCALRC=1

# Unset these are face the wrath of KAHN!
unset GIT_BASE

echo "Copying devstack-vm-gate-wrap.sh"
cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
echo "Running safe-devstack-vm-gate-wrap.sh"
./safe-devstack-vm-gate-wrap.sh

echo "========= Host Setup Logs ==========="
zcat $WORKSPACE/logs/devstack-gate-setup-host.txt.gz
echo "========= Workspace Setup Logs ==========="
zcat $WORKSPACE/logs/devstack-gate-setup-workspace-new.txt.gz

# Restore WORKSPACE
OS_WORKSPACE=$WORKSPACE
export WORKSPACE=$SAVED_WORKSPACE
cp -r $OS_WORKSPACE/logs $WORKSPACE
cp -A /opt/stack/new/logs/q-odl-karaf* $WORKSPACE/logs
# Unzip the logs to make them easier to view
gunzip $WORKSPACE/logs/*.gz
