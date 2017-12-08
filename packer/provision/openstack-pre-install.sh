#!/bin/bash

# add in a test copr repo
wget http://copr.fedoraproject.org/coprs/tykeal/odl-updates/repo/epel-7/tykeal-odl-updates-epel-7.repo -O /etc/yum.repos.d/tykeal-odl-updates-epel-7.repo

# force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# add in a test copr repo
yum install -y perl-XML-XPath python-pip python-six

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
echo "---> Install EPEL"
yum install epel-release
echo "---> Install chrony"
yum install chrony wget -y
yum install java-1.8.0-openjdk-devel -y
yum install -y centos-release-openstack-${branch_name}
yum install crudini -y
yum install mariadb galera mariadb-galera-server mariadb-server python2-PyMySQL -y
yum install rabbitmq-server -y
yum install memcached python-memcached -y
yum install openstack-keystone httpd mod_wsgi -y
yum install openstack-glance -y
yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute -y
yum install openstack-neutron openstack-neutron-ml2 ebtables -y
echo '---> Installing openvswitch from relevant openstack branch'
yum install -y --nogpgcheck openvswitch


# vim: sw=4 ts=4 sts=4 et :
