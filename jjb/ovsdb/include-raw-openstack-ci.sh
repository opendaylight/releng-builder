#!/bin/bash
#
# NOTE: This file takes two jobs from the OpenStack infra and
#       puts them here. See here:
#
# https://github.com/openstack-infra/project-config/blob/master/jenkins/jobs/networking-odl.yaml

export PATH=$PATH:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin

# *SIGH*. This is required to get lsb_release
sudo yum -y install redhat-lsb-core indent python-testrepository

echo "Making /opt/stack/new jenkins:jenkins"
sudo /usr/sbin/groupadd jenkins
sudo mkdir -p /opt/stack/new
sudo chown -R jenkins:jenkins /opt/stack/new
sudo bash -c 'echo "jenkins ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
sudo bash -c 'echo "stack ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'

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
export DEVSTACK_GATE_TEMPEST=1
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

# Unset this because it's set by the underlying Jenkins node ...
unset GIT_BASE

# Only run certain tempest tests
export DEVSTACK_GATE_TEMPEST_REGEX="tempest.api.network.test_networks \
                                    tempest.api.network.test_networks_negative"

# Specifically set the services we want
#OVERRIDE_ENABLED_SERVICES=q-svc,q-dhcp,q-l3,q-meta,quantum,key,g-api,g-reg,n-api,n-crt,n-obj,n-cpu,n-cond,n-sch,n-xvnc,n-cauth,h-eng,h-api,h-api-cfn,h-api-cw,rabbit,tempest,mysql

# Enable ODL debug logs and set memory parameters
export ODL_NETVIRT_DEBUG_LOGS=True
export ODL_JAVA_MIN_MEM=512m
export ODL_JAVA_MAX_MEM=784m
export ODL_JAVA_MAX_PERM_MEM=784m

# Trim down the boot wait time
export ODL_BOOT_WAIT=30

echo "Copying devstack-vm-gate-wrap.sh"
cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
echo "Running safe-devstack-vm-gate-wrap.sh"
./safe-devstack-vm-gate-wrap.sh
# Save the return value so we can exit with this
DGRET=$?

# Restore WORKSPACE
OS_WORKSPACE=$WORKSPACE
export WORKSPACE=$SAVED_WORKSPACE

# Copy all the logs
cp -r $OS_WORKSPACE/logs $WORKSPACE
cp -a /opt/stack/new/logs/q-odl-karaf* $WORKSPACE/logs
mkdir -p $WORKSPACE/logs/opendaylight
cp -a /opt/stack/new/opendaylight/distribution*/etc $WORKSPACE/logs/opendaylight
# Unzip the logs to make them easier to view
gunzip $WORKSPACE/logs/*.gz

exit $DGRET
