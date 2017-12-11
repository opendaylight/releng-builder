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

# Needed by autorelease scripts
yum install -y xmlstarlet

# Needed by docs project
yum install -y graphviz

# Needed by deploy test
yum install -y sshpass

#########################
# Integration/Packaging #
#########################

# Install software for building RPMs
yum install -y fedora-packager

# Needed for vsemprovider build in vtn project to enable C# compilation.
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
# Add the mono tools repository
yum-config-manager -y --add-repo http://download.mono-project.com/repo/centos/
# Install the mono toolchain and nuget
yum -y install mono-complete nuget

# Needed by TSDR
echo "---> Installing the Hbase Server..."
mkdir /tmp/Hbase
cd /tmp/Hbase
wget -nv https://archive.apache.org/dist/hbase/hbase-0.94.27/hbase-0.94.27.tar.gz
tar -xvf hbase-0.94.27.tar.gz

# Needed by TSDR
echo "---> Installing the Cassandra Server..."
mkdir /tmp/cassandra
cd /tmp/cassandra
wget -nv https://archive.apache.org/dist/cassandra/2.1.16/apache-cassandra-2.1.16-bin.tar.gz
tar -xvf apache-cassandra-2.1.16-bin.tar.gz

# Generally useful for all projects
echo "---> Installing the Elasticsearch node..."
mkdir /tmp/elasticsearch
cd /tmp/elasticsearch
wget -nv https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.5.tar.gz
tar -xvzf elasticsearch-1.7.5.tar.gz

# Installs Hashicorp's Packer binary, required for {verify,merge}-packer jobs
mkdir /tmp/packer
cd /tmp/packer
wget -nv https://releases.hashicorp.com/packer/1.1.3/packer_1.1.3_linux_amd64.zip
unzip packer_1.1.3_linux_amd64.zip -d /usr/local/bin/
# rename packer to avoid conflict with binary in cracklib
mv /usr/local/bin/packer /usr/local/bin/packer.io

# Check out quagga , compile and install for router functionalities
echo "Installing the Quagga..."
mkdir -p /tmp/build_quagga
cd /tmp/build_quagga
git clone https://github.com/6WIND/zrpcd.git
cd zrpcd
git checkout 20170731
chmod a+x /tmp/build_quagga/zrpcd/pkgsrc/dev_compile_script.sh
/tmp/build_quagga/zrpcd/pkgsrc/dev_compile_script.sh -d -b -t

# Removing the build_quagga folder
rm -rf /tmp/build_quagga/
