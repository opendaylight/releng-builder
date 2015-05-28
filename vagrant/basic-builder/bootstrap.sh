#!/bin/bash

# vim: sw=4 ts=4 sts=4 et tw=72 :

yum clean all

# Make sure the system is fully up to date
yum update -q -y

# The following packages are not needed by all projects, but they are
# needed by enough to make them useful everywhere
yum install -q -y @development perl-{Digest-SHA,ExtUtils-MakeMaker} \
    ant {boost,gtest,json-c,libcurl,libxml2,libvirt,openssl}-devel \
    {readline,unixODBC}-devel yum-utils

# tcpmd5 is wanting to do 32bit ARM cross-compilation and is specifically
# requesting the following be installed (note the kernel headers are
# going to be the x86_64 package as there aren't separate 32bit and
# x86_64 packages for them
yum install -q -y glibc-devel.i686 kernel-headers

# The following is needed by opendove, if this is to be perfomed against
# an EL6 system some of these packages are not availalble (or at the
# wrong version) in publically available repositories as such this
# should only really be done on an EL7 (or F18+) system
yum install -q -y {jansson,libevent,libnl,libuuid}-devel \
    python-{devel,virtualenv,setuptools,pip}

#The following is needed for the new code in vtn project.
#these packages will enable C# compilation.
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
#Added the mono tools repository
yum-config-manager -q -y --add-repo http://origin-download.mono-project.com/repo/centos6/
#Install the nuget binary
yum install -q -y http://origin-download.mono-project.com/repo/centos/n/nuget/nuget-2.8.3+md58+dhx1-0.noarch.rpm
#install the mono toolchain
yum -q -y install mono-complete
