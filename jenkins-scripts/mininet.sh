#!/bin/bash

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
EOF

# for whatever reason netopeer & CPqD aren't installed (they weren't in
# one of the yum repos we were hooked up to when the base image was
# built, they are now. Make sure they're install
yum install -q -y netopeer-server-sl CPqD-ofsoftswitch13

# the vagrant configuration for netopeer doesn't configure SSH correctly
# as it uses and here document via echo and not cat fix that
cat << EOSSH >> /etc/ssh/sshd_config

# Added for netconf / netopeer testing
Port 22
Port 830
Subsystem netconf /usr/bin/netopeer-server-sl
EOSSH

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

# make sure the firewall is stopped
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
