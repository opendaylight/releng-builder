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
