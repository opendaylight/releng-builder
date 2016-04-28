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

if [ -f hbase-0.94.15.tar.gz ]
then
    echo "Installing the Hbase Server..."
    tar -xvf hbase-0.94.15.tar.gz
else
    wget --no-verbose http://apache.osuosl.org/hbase/hbase-0.94.27/hbase-0.94.27.tar.gz
    echo "Installing the Hbase Server..."
    tar -xvf hbase-0.94.27.tar.gz
    mv hbase-0.94.27 hbase-0.94.15
fi

#Installation of Cassandra


mkdir /tmp/cassandra
cd /tmp/cassandra

wget --no-verbose http://archive.apache.org/dist/cassandra/2.1.12/apache-cassandra-2.1.12-bin.tar.gz

if [ -f apache-cassandra-2.1.12-bin.tar.gz ]
then
    echo "Installing the Cassandra Server..."
    tar -xvf apache-cassandra-2.1.12-bin.tar.gz
else
    wget --no-verbose http://apache.osuosl.org/cassandra/2.1.14/apache-cassandra-2.1.14-bin.tar.gz
    echo "Installing the Cassandra Server..."
    tar -xvf apache-cassandra-2.1.14-bin.tar.gz
    mv apache-cassandra-2.1.14 apache-cassandra-2.1.12
fi

cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF
