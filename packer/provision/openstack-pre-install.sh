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
echo "---> Install EPEL, wget for some downloading"
yum install epel-release yum-utils wget -y
echo "---> Install chrony"
yum install chrony -y
echo "--> Configure Chrony"
echo "allow 0.0.0.0/0" | tee -a /etc/chrony.conf

echo "--> Opendaylight Dependency"
yum install java-1.8.0-openjdk-devel -y

echo "--> Required for Openstack Packages"
yum install -y centos-release-openstack-${branch_name}
echo "--> Required for All Configuration"
yum install crudini -y

echo "---> Database For Openmstack Control Services"
yum install mariadb mariadb-server python2-PyMySQL -y
echo "--> MYSQL Configurations"
touch /etc/my.cnf.d/openstack.cnf
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld bind-address 0.0.0.0
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld default-storage-engine innodb
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld innodb_file_per_table innodb
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld max_connections 4096
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld collation-server utf8_general_ci
crudini --set --inplace /etc/my.cnf.d/openstack.cnf mysqld character-set-server utf8
sudo systemctl start mariadb.service
sudo mysqladmin -u root password mysql
echo "--> Provide all Access to the root user"
sudo mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON *.* TO '\''root'\''@'\''%'\'' identified by '\''mysql'\'';'
sudo systemctl enable mariadb


echo "--> Configure Rabbit MQ for Messages"
yum install rabbitmq-server -y
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack rabbit
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
systemctl enable rabbitmq-server


echo "--> Install and Configure memcached"
yum install memcached python-memcached -y
sudo crudini --set --inplace /etc/sysconfig/memcached '' OPTIONS "-l 0.0.0.0"
systemctl enable memcached.service

echo "--> Install and Configure Keystone"
yum install openstack-keystone httpd mod_wsgi -y
mysql -uroot -pmysql  -e 'CREATE DATABASE keystone CHARACTER SET utf8;'
mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON keystone.* TO '\''keystone'\''@'\''%'\'' identified by '\''keystone'\'';'


yum install openstack-glance -y
yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute -y
yum install openstack-neutron openstack-neutron-ml2 ebtables -y
echo '---> Installing openvswitch from relevant openstack branch'
yum install -y --nogpgcheck openvswitch

yum install -y haproxy


# vim: sw=4 ts=4 sts=4 et :
