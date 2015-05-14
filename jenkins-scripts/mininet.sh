#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# for whatever reason netopeer & CPqD aren't installed (they weren't in
# one of the yum repos we were hooked up to when the base image was
# built, they are now. Make sure they're install
yum install -q -y netopeer-server-sl CPqD-ofsoftswitch13

# netaddr and ipaddress libraries can be useful on this system as
# some tests are starting to push pyhon scripts/tools to this VM
# during CI tests
yum install -q -y python-{ipaddr,iptools,netaddr}

#For executing the CSIT test cases for VTN Coordinator
yum install -q -y uuid libxslt libcurl unixODBC json-c
chown jenkins /usr/local/vtn


# the vagrant configuration for netopeer doesn't configure SSH correctly
# as it uses and here document via echo and not cat fix that
cat << EOSSH >> /etc/ssh/sshd_config

# Added for netconf / netopeer testing
Port 22
Port 830
Subsystem netconf /usr/bin/netopeer-server-sl
EOSSH

# Configuring sshd to accept root login with password
sed -ie 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -ie 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
chattr +i /etc/ssh/sshd_config

# sshd has to get a restart because of the above
service sshd restart

# found out while doing testing to fix netopeer that the selinux perms
# aren't set correctly (thanks Rackspace for having an EL6 image that
# didn't have selinux on at first!) fix it so that the password can be
# set
/sbin/restorecon -R /etc

# According to Luis in RT7956 the controller SSH capabilities require
# that for NETCONF it uses a password (how broken!) So we're going to
# force a password onto the jenkins user
echo 'jenkins' | passwd -f --stdin jenkins

# netopeer doesn't work correctly for non-root users from what I'm
# seeing (at least for the initial connection). Let's allow the tests to
# get in as the root user since jenkins already has full sudo
echo 'root' | passwd -f --stdin root

# make sure the firewall is stopped
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
