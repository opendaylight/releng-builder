#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# Force any errors to cause the script and job to end in failure
set -xeu -o pipefail

# The following packages are not needed by all projects, but they are
# needed by enough to make them useful everywhere
yum install -y @development perl-{Digest-SHA,ExtUtils-MakeMaker} \
    ant {boost,gtest,json-c,libcurl,libxml2,libvirt,openssl}-devel \
    {readline,unixODBC}-devel yum-utils fedora-packager \
    libxslt-devel crudini

# Install python3 and dependencies, needed for Coala linting at least
yum install -y python34
yum install -y python34-{devel,virtualenv,setuptools,pip}

# Install python dependencies, useful generally
yum install -y python-{devel,virtualenv,setuptools,pip}

# Needed by autorelease scripts
yum install -y xmlstarlet

# Needed by docs project
yum install -y graphviz

# Needed by deploy test
yum install -y sshpass

# tcpmd5 is wanting to do 32bit ARM cross-compilation and is specifically
# requesting the following be installed (note the kernel headers are
# going to be the x86_64 package as there aren't separate 32bit and
# x86_64 packages for them
yum install -y glibc-devel.i686 kernel-headers

# Needed by opendove
yum install -y {jansson,libevent,libnl,libuuid}-devel

# Needed for vsemprovider build in vtn project to enable C# compilation.
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
# Add the mono tools repository
yum-config-manager -y --add-repo http://download.mono-project.com/repo/centos/
# Install the mono toolchain and nuget
yum -y install mono-complete nuget

# Needed by TSDR
echo "Installing the Hbase Server..."
mkdir /tmp/Hbase
cd /tmp/Hbase
wget --no-verbose http://apache.osuosl.org/hbase/hbase-0.94.27/hbase-0.94.27.tar.gz
tar -xvf hbase-0.94.27.tar.gz

# Needed by TSDR
echo "Installing the Cassandra Server..."
mkdir /tmp/cassandra
cd /tmp/cassandra
wget --no-verbose http://apache.osuosl.org/cassandra/2.1.16/apache-cassandra-2.1.16-bin.tar.gz
tar -xvf apache-cassandra-2.1.16-bin.tar.gz

# Generally useful for all projects
echo "Installing the Elasticsearch node..."
mkdir /tmp/elasticsearch
cd /tmp/elasticsearch
wget --no-verbose https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.5.tar.gz
tar -xvzf elasticsearch-1.7.5.tar.gz

# Installs Hashicorp's Packer binary, required for {verify,merge}-packer jobs
mkdir /tmp/packer
cd /tmp/packer
wget https://releases.hashicorp.com/packer/0.12.2/packer_0.12.2_linux_amd64.zip
unzip packer_0.12.2_linux_amd64.zip -d /usr/local/bin/
# rename packer to avoid conflict with binary in cracklib
mv /usr/local/bin/packer /usr/local/bin/packer.io

# Needed for Coala linting, Markdown and Dockerfile bears in particular
npm install remark-cli dockerfile_lint
