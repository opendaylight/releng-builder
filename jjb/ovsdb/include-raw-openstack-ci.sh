#!/bin/bash

export PATH=$PATH:/bin:/sbin:/usr/sbin
export DEVSTACKDIR=$WORKSPACE/$BUILD_TAG
mkdir $DEVSTACKDIR
cd $DEVSTACKDIR

cat <<EOL > firewall.sh
sudo iptables -I INPUT -p tcp --dport 5672 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 9292 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 9696 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 35357 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 6080 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8773 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 8472 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 4789 -j ACCEPT

# For the client
sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8774 -j ACCEPT

# For ODL
sudo iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
EOL
chmod +x firewall.sh

env
cat $DEVSTACKDIR/firewall.sh
$DEVSTACKDIR/firewall.sh

# FIXME: update version of pip being used here
curl -O https://pypi.python.org/packages/source/p/pip/pip-1.4.1.tar.gz
tar xvfz pip-1.4.1.tar.gz
cd pip-1.4.1
sudo -E python setup.py install
sudo pip install testtools

sudo mkdir -p /opt/stack
sudo chown $(whoami) /opt/stack
sudo chmod 755 /opt/stack
cd /opt/stack

# Workaround for bug:
# https://bugs.launchpad.net/devstack/+bug/1276297
sudo rm -rf /usr/lib/python2.7/site-packages/oslo*

# Workaround for "keystone not found" issues
sudo rm -rf /usr/lib/python2.7/site-packages/*client*

# Workaround: Pull neutron first
cd /opt/stack
git clone -q git://git.openstack.org/openstack/neutron.git
cd neutron
sudo python ./setup.py -q install

cd $DEVSTACKDIR

sudo yum -y install qemu libvirt-daemon
git clone https://github.com/openstack-dev/devstack.git
cd devstack

####
# Specify changeset being worked on if it's networking-odl
####
if [ "$GERRIT_PROJECT" == "stackforge/networking-odl" ]; then
    cat <<EOLLC > local.conf
[[local|localrc]]
enable_plugin networking-odl https://$GERRIT_HOST/$GERRIT_PROJECT $GERRIT_REFSPEC
EOLLC
else
    cat <<EOLLC > local.conf
[[local|localrc]]
enable_plugin networking-odl https://github.com/stackforge/networking-odl
EOLLC
fi

cat <<EOLLC >> local.conf
LOGFILE=stack.sh.log
SCREEN_LOGDIR=/opt/stack/data/log
VERBOSE=True
LOG_COLOR=False
RECLONE=yes
GIT_TIMEOUT=0
GIT_BASE=https://git.openstack.org

# Only uncomment the below two lines if you are running on Fedora
disable_service swift
disable_service rabbit
enable_service qpid
enable_service n-cpu
enable_service n-cond
disable_service n-net
enable_service q-svc
enable_service q-dhcp
enable_service q-l3
enable_service q-meta
enable_service quantum
enable_service tempest

API_RATE_LIMIT=False

Q_PLUGIN=ml2
Q_ML2_PLUGIN_MECHANISM_DRIVERS=logger,opendaylight
ENABLE_TENANT_TUNNELS=True

ODL_MODE=allinone
ODL_NETVIRT_DEBUG_LOGS=True
ODL_MGR_IP=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//')
ODL_ARGS="-Xmx1024m -XX:MaxPermSize=512m"
ODL_BOOT_WAIT=90

VNCSERVER_LISTEN=0.0.0.0

HOST_NAME=$(hostname)
SERVICE_HOST_NAME=$(hostname)
HOST_IP=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//')
SERVICE_HOST=$(hostname)

MYSQL_HOST=$(hostname)
RABBIT_HOST=$(hostname)
GLANCE_HOSTPORT=$(hostname):9292
KEYSTONE_AUTH_HOST=$(hostname)
KEYSTONE_SERVICE_HOST=$(hostname)

MYSQL_PASSWORD=mysql
RABBIT_PASSWORD=rabbit
QPID_PASSWORD=rabbit
SERVICE_TOKEN=service
SERVICE_PASSWORD=admin
ADMIN_PASSWORD=admin
EOLLC

# Add Neutron specific config if required
if [ "$GERRIT_PROJECT" == "openstack/neutron" ]; then
    cat <<EOLLC >> local.conf
NEUTRON_REPO=https://$GERRIT_HOST/$GERRIT_PROJECT
NEUTRON_BRANCH=$GERRIT_REFSPEC
EOLLC
fi

cat local.conf

####
# Clone the changeset being worked on if it's devstack
####
if [ "$GERRIT_PROJECT" == "openstack-dev/devstack" ]; then
    git fetch https://$GERRIT_HOST/$GERRIT_PROJECT $GERRIT_REFSPEC && git checkout FETCH_HEAD
fi

# Run devstack
./stack.sh

if [ "$?" != "0" ]; then
    echo "stack.sh failed"
    # Copy logs off
    mkdir -p $WORKSPACE/logs/devstack
    mkdir -p $WORKSPACE/logs/opendaylight
    cp -r /opt/stack/data/log/* $WORKSPACE/logs/devstack
    cp -r $DEVSTACKDIR/devstack/stack.sh.log* $WORKSPACE/logs
    cp -r $DEVSTACKDIR/devstack/local.conf $WORKSPACE/logs
    cp -r /opt/stack/opendaylight/*/logs $WORKSPACE/logs/opendaylight
    cp -r /opt/stack/opendaylight/*/data/log $WORKSPACE/logs/opendaylight
    cp -r /opt/stack/opendaylight/*/etc $WORKSPACE/logs/opendaylight
    tar cvzf $WORKSPACE/opendaylight-full-logs.tgz $WORKSPACE/logs
    exit 1
fi

# running tempest
if [[ -n ${BUILD_ID} ]]; then
    cd /opt/stack/tempest

    # put all the info in the following file for processing later
    log_for_review=odl_tempest_test_list.txt

    echo "Running tempest tests:" > /tmp/${log_for_review}
    echo "" >> /tmp/${log_for_review}
    testr init > /dev/null 2>&1 || true
    cmd="testr run  tempest.api.network.test_networks"
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
fi


# Copy logs off
mkdir -p $WORKSPACE/logs/devstack
mkdir -p $WORKSPACE/logs/tempest
mkdir -p $WORKSPACE/logs/opendaylight
cp -r /opt/stack/tempest/tempest.log* $WORKSPACE/logs/tempest
cp -r /opt/stack/data/log/* $WORKSPACE/logs/devstack
cp -r /opt/stack/opendaylight/*/logs $WORKSPACE/logs/opendaylight
cp -r /opt/stack/opendaylight/*/data/log $WORKSPACE/logs/opendaylight
cp -r /opt/stack/opendaylight/*/etc $WORKSPACE/logs/opendaylight
cp -r /tmp/${log_for_review} $WORKSPACE/logs
cp -r /tmp/${log_for_review} $WORKSPACE
cp -r $DEVSTACKDIR/devstack/stack.sh.log* $WORKSPACE/logs
cp -r $DEVSTACKDIR/devstack/local.conf $WORKSPACE/logs
tar cvzf $WORKSPACE/opendaylight-full-logs.tgz $WORKSPACE/logs
