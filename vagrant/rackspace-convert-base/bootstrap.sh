#!/bin/bash

# vim: ts=4 sw=4 sts=4 et tw=72 :

# Handle the occurance where SELINUX is actually disabled
if [ `grep SELINUX=permissive /etc/selinux/config` ]; then
    # make sure that the filesystem is properly labelled.
    # it could be not fully labeled correctly if it was just switched
    # from disabled, the autorelabel misses some things
    # skip relabelling on /dev as it will generally throw errors
    restorecon -R -e /dev /

    # enable enforcing mode from the very start
    setenforce enforcing

    # configure system for enforcing mode on next boot
    sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
else
    sed -i 's/SELINUX=disabled/SELINUX=permissive/' /etc/selinux/config
    touch /.autorelabel

    echo "*******************************************"
    echo "** SYSTEM REQUIRES A RESTART FOR SELINUX **"
    echo "*******************************************"
fi

yum clean all -q
yum update -y -q

# add in components we need or want on systems
yum install -y -q @base unzip xz puppet git perl-XML-XPath

# All of our systems require Java (because of Jenkins)
# Install all versions of the OpenJDK devel but force 1.7.0 to be the
# default

yum install -y -q 'java-*-openjdk-devel'
alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64

# To handle the prompt style that is expected all over the environment
# with how use use robotframework we need to make sure that it is
# consistent for any of the users that are created during dynamic spin
# ups
echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

# Do any Distro specific installations here
echo "Checking distribution"
if [ `/usr/bin/facter operatingsystem` = "Fedora" ]; then
    echo "---> Fedora found"
    echo "No extra steps for Fedora"
else
    if [ `/usr/bin/facter operatingsystemrelease | /bin/cut -d '.' -f1` = "7" ]; then
        echo "---> CentOS 7"
        echo "No extra steps currently for CentOS 7"
    else
        echo "---> CentOS 6"
        echo "Installing ODL YUM repo"
        yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
    fi
fi
