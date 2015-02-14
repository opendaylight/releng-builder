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

curl -O https://pypi.python.org/packages/source/p/pip/pip-1.4.1.tar.gz
tar xvfz pip-1.4.1.tar.gz
cd pip-1.4.1
sudo -E python setup.py install
sudo pip install testtools

sudo mkdir -p /opt/stack
sudo chown $(whoami) /opt/stack
sudo chmod 755 /opt/stack
cd /opt/stack
#git clone git://git.openstack.org/openstack/tempest.git
#git clone https://git.openstack.org/openstack/tempest.git
#cd tempest
#sudo python ./setup.py install

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

## Pull down stackforge/networking-odl -- see enable_plugin
#cd /opt/stack
#git clone -q git://git.openstack.org/stackforge/networking-odl.git
#cd networking-odl
#if [ "$GERRIT_PROJECT" == "stackforge/networking-odl" ]; then
#    git fetch https://$GERRIT_HOST/$GERRIT_PROJECT $GERRIT_REFSPEC && git checkout FETCH_HEAD
#fi
#sudo python ./setup.py -q install

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
#OFFLINE=True
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

#Q_HOST=$SERVICE_HOST
#HOST_IP=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//')
#HOST_IP=192.168.64.80

Q_PLUGIN=ml2
Q_ML2_PLUGIN_MECHANISM_DRIVERS=logger,opendaylight
#Q_ML2_PLUGIN_MECHANISM_DRIVERS=openvswitch
#enable_service q-agt
ENABLE_TENANT_TUNNELS=True
#NEUTRON_REPO=https://github.com/CiscoSystems/neutron.git
#NEUTRON_BRANCH=bp/ml2-opendaylight-mechanism-driver

ODL_MODE=allinone
ODL_NETVIRT_DEBUG_LOGS=True
#ODL_MGR_IP=127.0.0.1
ODL_MGR_IP=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//')
ODL_ARGS="-Xmx1024m -XX:MaxPermSize=512m"
ODL_BOOT_WAIT=90

#VNCSERVER_PROXYCLIENT_ADDRESS=192.168.64.80
VNCSERVER_LISTEN=0.0.0.0

HOST_NAME=$(hostname)
#SERVICE_HOST_NAME=${HOST_NAME}
SERVICE_HOST_NAME=$(hostname)
HOST_IP=$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//')
SERVICE_HOST=$(hostname)

#SERVICE_HOST=localhost
#HOST_IP=127.0.0.1

#FLOATING_RANGE=192.168.74.0/24
#PUBLIC_NETWORK_GATEWAY=192.168.74.253
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

# cat <<EOLLC >> local.conf
# [[post-config|/etc/neutron/plugins/ml2/ml2_conf.ini]]
# [ml2_odl]
# url=http://$(ip addr | grep inet | grep eth0 | awk -F" " '{print $2}'| sed -e 's/\/.*$//'):8080/controller/nb/v2/neutron
# username=admin
# password=admin
# EOLLC

cat local.conf

# Clone the ODL devstack patches
#git fetch https://review.openstack.org/openstack-dev/devstack refs/changes/74/69774/17 && git checkout FETCH_HEAD

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

# Run a Tempest test and log results
#cd /opt/stack/tempest
#testr init
#testr run tempest.api.network.test_networks
#testr run tempest.scenario.test_network_basic_ops

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
