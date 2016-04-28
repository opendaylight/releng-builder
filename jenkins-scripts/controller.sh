#!/bin/bash

# disable the firewall
/bin/bash ./disable_firewall.sh

# install sshpass
yum install -y sshpass

# vim: sw=2 ts=2 sts=2 et :
# Installation of Hbase
mkdir /tmp/Hbase
cd /tmp/Hbase

wget --no-verbose https://archive.apache.org/dist/hbase/hbase-0.94.15/hbase-0.94.15.tar.gz

[ -f hbase-0.94.15.tar.gz ] && ( STR1="hbase-0.94.15.tar.gz" && STR2="hbase-0.94.15" ) || \
 ( wget --no-verbose http://apache.osuosl.org/hbase/hbase-0.94.27/hbase-0.94.27.tar.gz && \
 STR1="hbase-0.94.27.tar.gz" && STR2="hbase-0.94.27" )

echo "Installing the Hbase Server..."
tar -xvf $STR1
mv $STR2 hbase-0.94.15


#Installation of Cassandra


mkdir /tmp/cassandra
cd /tmp/cassandra

wget --no-verbose http://archive.apache.org/dist/cassandra/2.1.12/apache-cassandra-2.1.12-bin.tar.gz

[ -f apache-cassandra-2.1.12-bin.tar.gz ] && ( STR1="apache-cassandra-2.1.12-bin.tar.gz" && \
 STR2="apache-cassandra-2.1.12" ) || \
 ( wget --no-verbose http://apache.osuosl.org/cassandra/2.1.14/apache-cassandra-2.1.14-bin.tar.gz && \
 STR1="apache-cassandra-2.1.14-bin.tar.gz" && STR2="apache-cassandra-2.1.14" )

echo "Installing the Cassandra Server..."
tar -xvf $STR1
mv $STR2 apache-cassandra-2.1.12

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF
