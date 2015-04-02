#!/bin/bash

# According to Luis in RT7956 the controller SSH capabilities require
# that for NETCONF it uses a password (how broken!) So we're going to
# force a password onto the jenkins user
echo 'jenkins' | passwd -f --stdin jenkins

# make sure the firewall is stopped
service iptables stop

# vim: sw=2 ts=2 sts=2 et :
