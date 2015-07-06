#!/bin/bash

yum clean all
yum install -y python-virtualenv xmlstarlet

# add in mono components for VTN
yum install -y yum-utils
#The following is needed for the new code in vtn project.
#these packages will enable C# compilation.
rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
#Added the mono tools repository
yum-config-manager -q -y --add-repo http://origin-download.mono-project.com/repo/centos6
#Install the nuget binary
yum install -q -y http://origin-download.mono-project.com/repo/centos/n/nuget/nuget-2.8.3+md58+dhx1-0.noarch.rpm
#install the mono toolchain
yum -q -y install mono-complete

# vim: sw=2 ts=2 sts=2 et :
