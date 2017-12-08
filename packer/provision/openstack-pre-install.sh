#!/bin/bash

# add in a test copr repo
wget http://copr.fedoraproject.org/coprs/tykeal/odl-updates/repo/epel-7/tykeal-odl-updates-epel-7.repo -O /etc/yum.repos.d/tykeal-odl-updates-epel-7.repo

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# add in a test copr repo
yum install -y perl-XML-XPath python-pip python-six bind-utils

# install crudini command line tool for editing config files
yum install -y crudini

echo '---> Updating net link setup'
if [ ! -f /etc/udev/rules.d/80-net-setup-link.rules ]; then
    ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules
fi

echo '---> Pre-installing all openstack rpms'
# shellcheck disable=SC2154
branch=${os_branch}
# strip the "stable" off of the branch
branch_name=$(cut -d'/' -f2 <<< ${branch})

echo "--> Install all rpms that are needed to run Openstack Node"
echo "---> Install EPEL, wget for downloading images"
yum install epel-release yum-utils wget -y
echo "---> Install chrony"
yum install chrony -y
echo "--> Configure Chrony"

echo "--> Opendaylight Dependency"
yum install java-1.8.0-openjdk-devel -y

echo "--> Required for Openstack Packages"
yum install -y centos-release-openstack-${branch_name}
echo "--> Required for All Configuration"
yum install crudini -y
yum install python-openstackclient -y

echo "---> Database For Openstack Control Services"
yum install mariadb mariadb-server python2-PyMySQL -y

echo "--> Configure Rabbit MQ for Messages"
yum install rabbitmq-server -y

echo "--> Install and Configure memcached"
yum install memcached python-memcached -y

echo  "--> Install Glance and its dependencies"
yum install openstack-glance -y

echo  "--> Install All nova Applications"
yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute libvirtd -y

cat >> /etc/httpd/conf.d/00-nova-placement-api.conf << EOF
<Directory /usr/bin>
  <IfVersion >= 2.4>
    Require all granted
  </IfVersion>
  <IfVersion < 2.4>
    Order allow,deny
    Allow from all
  </IfVersion>
</Directory>
EOF

echo "--> Install all components required for Neutron"
yum install openstack-neutron openstack-neutron-ml2 ebtables -y

echo '---> Installing openvswitch from relevant openstack branch'
yum install -y --nogpgcheck openvswitch
systemctl enable openvswitch
crudini --verbose --set --inplace /usr/lib/systemd/system/ovsdb-server.service Service Restart always
crudini --verbose --set --inplace /usr/lib/systemd/system/ovs-vswitchd.service Service Restart always
systemctl start openvswitch
ovs-vsctl add-br br-flat1
ovs-vsctl add-br br-flat2
ovs-vsctl add-br br-physnet1
ovs-vsctl add-br br-vlantest

echo "---> Install haproxy for clusteringi and configure basic Settings"
yum install -y haproxy nfs-utils
mkdir --mode=777 /instances

echo "--> Initial Configuration for HAProxy"
cat > /etc/haproxy/haproxy.cfg << EOF
global
 chroot /var/lib/haproxy
 daemon
 group haproxy
 maxconn 4000
 pidfile /var/run/haproxy.pid
 user haproxy

defaults
 log global
 maxconn 4000
 option redispatch
 retries 3
 timeout http-request 10s
 timeout queue 1m
 timeout connect 10s
 timeout client 1m
 timeout server 1m
 timeout check 10s
EOF

echo "--> Create Repo file for installing Openstack Plugins from the test"
cat > /etc/yum.repos.d/os-plugins.repo << EOF
[os-plugins-repo]
baseurl=https://trunk.rdoproject.org/centos7-${branch_name}/consistent/
enabled=1
gpgcheck=0
EOF

echo "--> Download Images for Testing "
mkdir --mode=777 -p /opt/images
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img -O /opt/images/cirros40.img
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -O /opt/images/cirros35.img
wget https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images/Fedora-Cloud-Base-27-1.6.x86_64.qcow2 -O /opt/images/fedora.qcow2

#Add Stuff for sudo access to jenkins user
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# vim: sw=4 ts=4 sts=4 et :
