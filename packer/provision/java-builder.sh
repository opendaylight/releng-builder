#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

# The following packages are not needed by all projects, but they are
# needed by enough to make them useful everywhere
yum install -y @development perl-{Digest-SHA,ExtUtils-MakeMaker} \
    ant {boost,gtest,json-c,libcurl,libxml2,libvirt,openssl}-devel \
    {readline,unixODBC}-devel yum-utils

#Install python3 and dependencies
yum install -y python34
yum install -y python34-{devel,virtualenv,setuptools,pip}

# Install python dependencies
yum install -y python-{devel,virtualenv,setuptools,pip}

# Needed by autorelease scripts
yum install -y xmlstarlet

# sshpass for the current deploy test to be runable immediatelly after
# build
yum install -y sshpass

# tcpmd5 is wanting to do 32bit ARM cross-compilation and is specifically
# requesting the following be installed (note the kernel headers are
# going to be the x86_64 package as there aren't separate 32bit and
# x86_64 packages for them
yum install -y glibc-devel.i686 kernel-headers

# The following is needed by opendove, if this is to be perfomed against
# an EL6 system some of these packages are not availalble (or at the
# wrong version) in publically available repositories as such this
# should only really be done on an EL7 (or F18+) system
yum install -y {jansson,libevent,libnl,libuuid}-devel

#The following is needed for the vsemprovider build in vtn project.
#these packages will enable C# compilation.
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
#Added the mono tools repository
yum-config-manager -y --add-repo http://download.mono-project.com/repo/centos/
#install the mono toolchain and nuget
yum -y install mono-complete nuget
#end changes for vsemprovider in VTN

# The following installs hashicorp's packer binary which is required  for
# the {verify,merge}-packer jobs
mkdir /tmp/packer
cd /tmp/packer
wget https://releases.hashicorp.com/packer/0.10.1/packer_0.10.1_linux_amd64.zip
unzip packer_0.10.1_linux_amd64.zip -d /usr/local/bin/
# rename packer to avoid conflict with binary in cracklib
mv /usr/local/bin/packer /usr/local/bin/packer.io
