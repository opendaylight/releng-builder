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

# Unset this because it's set by the underlying Jenkins node ...
unset GIT_BASE

# Specifically set the services we want
OVERRIDE_ENABLED_SERVICES=q-svc,q-dhcp,q-l3,q-meta,quantum,key,g-api,g-reg,n-api,n-crt,n-obj,n-cpu,n-cond,n-sch,n-xvnc,n-cauth,h-eng,h-api,h-api-cfn,h-api-cw,rabbit,tempest,mysql

# Enable ODL debug logs and set memory parameters
ODL_NETVIRT_DEBUG_LOGS=True
ODL_JAVA_MIN_MEM=256m
ODL_JAVA_MAX_MEM=512m
ODL_JAVA_MAX_PERM_MEM=512m

echo "Copying devstack-vm-gate-wrap.sh"
cp devstack-gate/devstack-vm-gate-wrap.sh ./safe-devstack-vm-gate-wrap.sh
echo "Running safe-devstack-vm-gate-wrap.sh"
./safe-devstack-vm-gate-wrap.sh
# Save the return value so we can exit with this
DGRET=$?

# Restore WORKSPACE
OS_WORKSPACE=$WORKSPACE
export WORKSPACE=$SAVED_WORKSPACE

# NOTE: We temporarily run tempest here
# running tempest
if [ "$DGRET" == "0" ]; then
    cd /opt/stack/new/tempest

    # Install testrepository
    sudo pip install testrepository

    # put all the info in the following file for processing later
    log_for_review=odl_tempest_test_list.txt

    echo "Running tempest tests:" > /tmp/${log_for_review}
    echo "" >> /tmp/${log_for_review}
    testr init > /dev/null 2>&1 || true
    cmd_api="tempest.api.network.test_networks \
             tempest.api.network.test_networks_negative \
             tempest.api.network.test_ports tempest.api.network.test_routers"
    cmd_net_basic="tempest.scenario.test_network_basic_ops"
    cmd="testr run $cmd_api $cmd_net_basic"
    echo "opendaylight-test:$ "${cmd}  >> /tmp/${log_for_review}
    ${cmd} >> /tmp/${log_for_review}
    echo "" >> /tmp/${log_for_review}
    echo "" >> /tmp/${log_for_review}

    x=$(grep "id=" /tmp/${log_for_review})
    y="${x//[()=]/ }"
    z=$(echo ${y} | awk '{print $3}' | sed 's/\,//g')

    #echo "x ($x) y ($y) z ($z)"

    echo "List of tempest tests ran (id="${z}"):" >> /tmp/${log_for_review}
    echo "" >> /tmp/${log_for_review}

    grep -ri successful   .testrepository/${z}  |  awk '{ gsub(/\[/, "\ ");  print $1 " " $2}' >> /tmp/${log_for_review}

    # Copy tempest logs
    mkdir -p $WORKSPACE/logs/tempest
    cp -r /opt/stack/new/tempest/tempest.log* $WORKSPACE/logs/tempest
    cp -r /tmp/${log_for_review} $WORKSPACE/logs
fi

# Copy all the logs
cp -r $OS_WORKSPACE/logs $WORKSPACE
cp -a /opt/stack/new/logs/q-odl-karaf* $WORKSPACE/logs
mkdir -p $WORKSPACE/logs/opendaylight
cp -a /opt/stack/new/opendaylight/distribution*/etc $WORKSPACE/logs/opendaylight
# Unzip the logs to make them easier to view
gunzip $WORKSPACE/logs/*.gz

exit $DGRET
