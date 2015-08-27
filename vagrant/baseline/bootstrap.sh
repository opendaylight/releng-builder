#!/bin/bash

# vim: ts=4 sw=4 sts=4 et tw=72 :

rh_systems() {
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

    echo "---> Updating operating system"
    yum clean all -q
    yum update -y -q

    # add in components we need or want on systems
    echo "---> Installing base packages"
    yum install -y -q @base unzip xz puppet git perl-XML-XPath

    # All of our systems require Java (because of Jenkins)
    # Install all versions of the OpenJDK devel but force 1.7.0 to be the
    # default

    echo "---> Configuring OpenJDK"
    yum install -y -q 'java-*-openjdk-devel'
    alternatives --set java /usr/lib/jvm/jre-1.7.0-openjdk.x86_64/bin/java
    alternatives --set java_sdk_openjdk /usr/lib/jvm/java-1.7.0-openjdk.x86_64
}

ubuntu_systems() {
    # Ignore SELinux since slamming that onto Ubuntu leads to
    # frustration

    echo "---> Updating operating system"
    apt-get update -qq
    apt-get upgrade -y --force-yes -qq

    # add in stuff we know we need
    echo "---> Installing base packages"
    apt-get install -y --force-yes -qq unzip xz-utils puppet git libxml-xpath-perl

    # install Java 7
    echo "---> Configuring OpenJDK"
    apt-get install -y --force-yes -qq openjdk-7-jdk
    
    # make jdk8 available
    add-apt-repository -y ppa:openjdk-r/ppa
    apt-get update -qq
    # We need to force openjdk-8-jdk to install
    apt-get install -y -qq openjdk-8-jdk

    # make sure that we still default to openjdk 7
    update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-7-openjdk-amd64/bin/javac
}

all_systems() {
    # To handle the prompt style that is expected all over the environment
    # with how use use robotframework we need to make sure that it is
    # consistent for any of the users that are created during dynamic spin
    # ups
    echo 'PS1="[\u@\h \W]> "' >> /etc/skel/.bashrc

    # Do any Distro specific installations here
    echo "Checking distribution"
    FACTER_OS=`/usr/bin/facter operatingsystem`
    case "$FACTER_OS" in
        RedHat|CentOS)
            if [ `/usr/bin/facter operatingsystemrelease | /bin/cut -d '.' -f1` = "7" ]; then
                echo
                echo "---> CentOS 7"
                echo "No extra steps currently for CentOS 7"
                echo
            else
                echo "---> CentOS 6"
                echo "Installing ODL YUM repo"
                yum install -q -y https://nexus.opendaylight.org/content/repositories/opendaylight-yum-epel-6-x86_64/rpm/opendaylight-release/0.1.0-1.el6.noarch/opendaylight-release-0.1.0-1.el6.noarch.rpm
            fi
        ;;
        *)
            echo "---> $FACTER_OS found"
            echo "No extra steps for $FACTER_OS"
        ;;
    esac
}

echo "---> Attempting to detect OS"
# OS selector
if [ -f /usr/bin/yum ]
then
    OS='RH'
else
    OS='UBUNTU'
fi

case "$OS" in
    RH)
        echo "---> RH type system detected"
        rh_systems
    ;;
    UBUNTU)
        echo "---> Ubuntu system detected"
        ubuntu_systems
    ;;
    *)
        echo "---> Unknown operating system"
    ;;
esac

# execute steps for all systems
all_systems
