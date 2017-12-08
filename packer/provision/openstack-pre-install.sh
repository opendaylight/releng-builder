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
yum install python-openstackclient -y

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
echo "--> Provide all Access to the root user"
systemctl start mariadb

sudo mysqladmin -u root password mysql
echo "Provide all Access to the root user"
sudo mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON *.* TO '\''root'\''@'\''%'\'' identified by '\''mysql'\'';'


echo "--> Configure Rabbit MQ for Messages"
yum install rabbitmq-server -y
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack rabbit
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

echo "--> Install and Configure memcached"
yum install memcached python-memcached -y
crudini --set --inplace /etc/sysconfig/memcached '' OPTIONS "-l 0.0.0.0"

echo "--> Install Keystone and its dependencies"
mysql -uroot -pmysql  -e 'CREATE DATABASE keystone CHARACTER SET utf8;'
mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON keystone.* TO '\''keystone'\''@'\''%'\'' identified by '\''keystone'\'';'
yum install openstack-keystone httpd mod_wsgi -y


echo  "--> Install Glance and its dependencies"
mysql -uroot -pmysql -e 'CREATE DATABASE glance CHARACTER SET utf8;'
mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON glance.* TO '\''glance'\''@'\''%'\'' identified by '\''glance'\'';'
yum install openstack-glance -y

echo  "--> Install All Components for nova"
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova_api CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova_cell0 CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova_api.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova_cell0.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'


yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute -y

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
sudo mysql -uroot -pmysql -e 'CREATE DATABASE neutron CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON neutron.* TO '\''neutron'\''@'\''%'\'' identified by '\''neutron'\'';'
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
echo "---> Needed for live Migration Cases"
systemctl enable rpcbind
mkdir /instances
chmod -R 777 /instances

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
mkdir -p /opt/images
wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img -O /opt/images/cirros40.img
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img -O /opt/images/cirros35.img
wget https://download.fedoraproject.org/pub/fedora/linux/releases/27/CloudImages/x86_64/images/Fedora-Cloud-Base-27-1.6.x86_64.qcow2 -O /opt/images/fedora.qcow2
chmod -R 777 /opt/images

# vim: sw=4 ts=4 sts=4 et :
