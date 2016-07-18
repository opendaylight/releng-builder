#!/bin/bash
# vim: sw=2 ts=2 sts=2 et :

yum clean all

#
# VTN
#

# Add mono components for VTN
yum install -y yum-utils
# The following is needed for the new code in VTN project
# These packages will enable C# compilation
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
# Add the mono tools repository
yum-config-manager -q -y --add-repo http://origin-download.mono-project.com/repo/centos
# Install the nuget binary
yum install -q -y http://origin-download.mono-project.com/repo/centos/n/nuget/nuget-2.8.3+md58+dhx1-0.noarch.rpm
# Install the mono toolchain
yum -q -y install mono-complete

#
# Integration/Packaging
#

# Install software for building RPMs
yum install -y fedora-packager

# Install software for building docs
yum install -y libxslt-devel



# disable the firewall
/bin/bash ./disable_firewall.sh

# install sshpass
yum install -y sshpass

# vim: sw=2 ts=2 sts=2 et :
# Installation of Hbase
mkdir /tmp/Hbase
cd /tmp/Hbase

wget --no-verbose http://apache.osuosl.org/hbase/hbase-0.94.27/hbase-0.94.27.tar.gz

echo "Installing the Hbase Server..."

tar -xvf hbase-0.94.27.tar.gz

#Installation of Cassandra


mkdir /tmp/cassandra
cd /tmp/cassandra

wget --no-verbose http://apache.osuosl.org/cassandra/2.1.14/apache-cassandra-2.1.14-bin.tar.gz

echo "Installing the Cassandra Server..."

tar -xvf apache-cassandra-2.1.14-bin.tar.gz

# Installation of Elasticsearch node

mkdir /tmp/elasticsearch
cd /tmp/elasticsearch

wget --no-verbose https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.5.tar.gz

echo "Installing the Elasticsearch node..."

tar -xvzf elasticsearch-1.7.5.tar.gz

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# install crudini command line tool for editing config files
yum install -y crudini
