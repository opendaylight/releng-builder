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

echo "-->Create directory for all install scripts"
mkdir -p /opt/openstack/install/
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

cat > /opt/openstack/install/setup_mysql.sh << EOF
sudo systemctl start mariadb
sudo mysqladmin -u root password mysql
echo "Provide all Access to the root user"
sudo mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON *.* TO '\''root'\''@'\''%'\'' identified by '\''mysql'\'';'
EOF
chmod +x /opt/openstack/install/setup_mysql.sh

echo "--> Configure Rabbit MQ for Messages"
yum install rabbitmq-server -y

cat > /opt/openstack/install/setup_rabbit.sh << EOF
sudo systemctl start rabbitmq-server.service	
sudo rabbitmqctl add_user openstack rabbit
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
EOF

echo "--> Install and Configure memcached"
yum install memcached python-memcached -y
crudini --set --inplace /etc/sysconfig/memcached '' OPTIONS "-l 0.0.0.0"

echo "--> Install Keystone and its dependencies"
yum install openstack-keystone httpd mod_wsgi -y

echo "--> Create Script to Configure"
cat > /opt/openstack/install/setup_keystone.sh << EOF
CONTROL_HOSTNAME=$1
mysql -uroot -pmysql  -e 'CREATE DATABASE keystone CHARACTER SET utf8;'
mysql -uroot -pmysql  -e 'GRANT ALL PRIVILEGES ON keystone.* TO '\''keystone'\''@'\''%'\'' identified by '\''keystone'\'';'
sudo crudini --verbose  --set --inplace /etc/keystone/keystone.conf database connection "mysql+pymysql://keystone:keystone@${CONTROL_HOSTNAME}/keystone"
sudo crudini --verbose  --set --inplace /etc/keystone/keystone.conf token provider "fernet"
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage bootstrap --bootstrap-password admin --bootstrap-admin-url http://${CONTROL_HOSTNAME}:35357/v3/ --bootstrap-internal-url http://${CONTROL_HOSTNAME}:5000/v3/ --bootstrap-public-url http://${CONTROL_HOSTNAME}:5000/v3/  --bootstrap-region-id RegionOne
echo "ServerName  ${CONTROL_HOSTNAME}"  | sudo tee -a etc/httpd/conf/httpd.conf

sudo ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
sudo systemctl enable httpd.service
sudo systemctl start httpd.service
EOF

cat > /opt/openstack/install/create_domain_service.sh << EOF_MAIN
CONTROL_HOSTNAME=$1
cat > /tmp/client_rc << EOF
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://${CONTROL_HOSTNAME}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
source /tmp/client_rc

openstack project create --domain default --description "Service Project" service

EOF_MAIN

echo  "--> Install Glance and its dependencies"
mysql -uroot -pmysql -e 'CREATE DATABASE glance CHARACTER SET utf8;'
mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON glance.* TO '\''glance'\''@'\''%'\'' identified by '\''glance'\'';'
yum install openstack-glance -y
cat > /opt/openstack/install/setup_glance.sh << EOF
CONTROL_HOSTNAME=$1
sudo mysql -uroot -pmysql -e 'CREATE DATABASE glance CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON glance.* TO '\''glance'\''@'\'${CONTROL_HOSTNAME}\'' identified by '\''glance'\'';ource /tmp/client_rc
openstack user create glance --domain default --password glance
openstack role add --project service --user glance admin

openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public http://${CONTROL_HOSTNAME}:9292
openstack endpoint create --region RegionOne image internal http://${CONTROL_HOSTNAME}:9292
openstack endpoint create --region RegionOne image admin http://${CONTROL_HOSTNAME}:9292
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf DEFAULT bind_host "0.0.0.0"
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf DEFAULT notification_driver "noop"
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:glance@${CONTROL_HOSTNAME}/glance"
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${CONTROL_HOSTNAME}:5000
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken memcached_servers ${CONTROL_HOSTNAME}:11211
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken auth_type password
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken project_domain_name default
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken user_domain_name default
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken project_name service
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken username glance
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf keystone_authtoken password glance
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf paste_deploy flavor keystone
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf glance_store stores "file,http"
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf glance_store default_store file
sudo crudini --verbose  --set --inplace /etc/glance/glance-api.conf glance_store filesystem_store_datadir  /var/lib/glance/images/
sudo chmod 640 /etc/glance/glance-api.conf
sudo chown root:glance /etc/glance/glance-api.conf

sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf DEFAULT bind_host "0.0.0.0"
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf DEFAULT notification_driver "noop"
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf database connection "mysql+pymysql://glance:glance@${CONTROL_HOSTNAME}/glance"
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${CONTROL_HOSTNAME}:5000
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken memcached_servers ${CONTROL_HOSTNAME}:11211
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken auth_type password
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken project_name service
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken username glance
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf keystone_authtoken password glance
sudo crudini --verbose  --set --inplace /etc/glance/glance-registry.conf paste_deploy flavor keystone

sudo su -s /bin/sh -c "glance-manage db_sync" glance

sudo systemctl enable openstack-glance-api.service
sudo systemctl start openstack-glance-api.service
sudo systemctl enable openstack-glance-registry.service
sudo systemctl start openstack-glance-registry.service

EOF

echo  "--> Install All Components for nova"


yum install openstack-nova-api openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler openstack-nova-placement-api openstack-nova-compute libvirtd -y


cat > /opt/openstack/install/setup_nova_api.sh << EOF
CONTROL_HOSTNAME=$1
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova_api CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'CREATE DATABASE nova_cell0 CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova_api.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON nova_cell0.* TO '\''nova'\''@'\''%'\'' identified by '\''nova'\'';'

source /tmp/client_rc
openstack user create nova --domain default --password nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region RegionOne compute public http://${CONTROL_HOSTNAME}:8774/v2.1
openstack endpoint create --region RegionOne compute internal http://${CONTROL_HOSTNAME}:8774/v2.1
openstack endpoint create --region RegionOne compute admin http://${CONTROL_HOSTNAME}:8774/v2.1
openstack user create placement --domain default --password placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public http://${CONTROL_HOSTNAME}:8778
openstack endpoint create --region RegionOne placement internal http://${CONTROL_HOSTNAME}:8778
openstack endpoint create --region RegionOne placement admin http://${CONTROL_HOSTNAME}:8778

sudo crudini --verbose  --set --inplace /etc/nova/nova.conf DEFAULT enabled_apis "osapi_compute,metadata"
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf DEFAULT transport_url "rabbit://openstack:rabbit@${CONTROL_HOSTNAME}"
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf DEFAULT my_ip ${CONTROL_NODE_IP}
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf DEFAULT use_neutron True
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf api_database connection  mysql+pymysql://nova:nova@${CONTROL_HOSTNAME}/nova_api
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf database connection  mysql+pymysql://nova:nova@${CONTROL_HOSTNAME}/nova
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf api auth_strategy keystone
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken auth_uri http://${CONTROL_HOSTNAME}:5000
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken memcached_servers ${CONTROL_HOSTNAME}:11211
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken auth_type password
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken project_domain_name default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken user_domain_name default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken project_name service
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken username nova
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf keystone_authtoken password nova
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf vnc enabled true
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf vnc vncserver_listen \${my_ip}
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf vnc vncserver_proxyclient_address \${my_ip}
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf glance api_servers http://${CONTROL_HOSTNAME}:9292
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf oslo_concurrency  lock_path /var/lib/nova/tmp

sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement os_region_name RegionOne
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement project_domain_name Default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement project_name service
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement auth_type password
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement user_domain_name Default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement auth_url http://${CONTROL_HOSTNAME}:35357/v3
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement username placement
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf placement password placement
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf scheduler discover_hosts_in_cells_interval 40


EOF


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

cat > /opt/openstack/install/setup_neutron_api.sh << EOF
CONTROL_HOSTNAME=$1
MY_HOSTNAME=$2
sudo mysql -uroot -pmysql -e 'CREATE DATABASE neutron CHARACTER SET utf8;'
sudo mysql -uroot -pmysql -e 'GRANT ALL PRIVILEGES ON neutron.* TO '\''neutron'\''@'\'%\'' identified by '\''neutron'\'';'
source /tmp/client_rc

openstack user create neutron --domain default --password neutron
openstack role add --project service --user neutron admin

openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne  network public http://${CONTROL_HOSTNAME}:9696
openstack endpoint create --region RegionOne  network internal http://${CONTROL_HOSTNAME}:9696
openstack endpoint create --region RegionOne  network admin http://${CONTROL_HOSTNAME}:9696

sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf database connection  mysql+pymysql://neutron:neutron@${CONTROL_HOSTNAME}/neutron
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT core_plugin ml2
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true


sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT transport_url rabbit://openstack:rabbit@${CONTROL_HOSTNAME}
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes true
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes true


sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken auth_uri http://${CONTROL_HOSTNAMR}:5000
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken memcached_servers ${CONTROL_HOSTNAME}:11211
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken auth_type password
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken project_name service
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken username neutron
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf keystone_authtoken password neutron

sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova auth_uri http://${CONTROL_HOSTNAME}:5000
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova memcached_servers ${CONTROL_HOSTNAME}:11211
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova auth_type password
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova project_domain_name default
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova user_domain_name default
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova project_name service
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova username nova
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf nova password nova

sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp
sudo crudini --verbose  --set --inplace /etc/neutron/neutron.conf OVS ovsdb_connection tcp:127.0.0.1:6641

sudo crudini --verbose  --set --inplace /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers "flat,vlan,vxlan"
sudo crudini --verbose  --set --inplace /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges 1:1000
sudo crudini --verbose  --set --inplace /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges  physnet1:1:4094,vlantest:1:4094 
sudo crudini --verbose  --set --inplace /etc/neutron/dhcp_agent.ini DEFAULT ovs_use_veth True
sudo crudini --verbose  --set --inplace /etc/neutron/dhcp_agent.ini DEFAULT interface_driver openvswitch
sudo crudini --verbose  --set --inplace /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true
sudo crudini --verbose  --set --inplace /etc/neutron/dhcp_agent.ini OVS ovsdb_connection tcp:127.0.0.1:6641
sudo crudini --verbose  --set --inplace /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip ${CONTROL_HOSTNAME}
sudo crudini --verbose  --set --inplace /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret metadata
sudo crudini --verbose  --set --inplace /etc/neutron/metadata_agent.ini OVS ovsdb_connection tcp:127.0.0.1:6641
	
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron url http://${CONTROL_HOSTNAME}:9696
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron auth_url http://${CONTROL_HOSTNAME}:35357
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron auth_type password
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron project_domain_name default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron user_domain_name default
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron region_name RegionOne
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron project_name service
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron username neutron
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron password neutron
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron service_metadata_proxy true
sudo crudini --verbose  --set --inplace /etc/nova/nova.conf neutron metadata_proxy_shared_secret metadata

EOF


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
