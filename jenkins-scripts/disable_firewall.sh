#!/bin/bash

# Add puppetlabs bin to $PATH
if [ -f "/etc/profile.d/puppet-agent.sh" ]; then
    source "/etc/profile.d/puppet-agent.sh"
fi

OS=$(facter operatingsystem)

case "$OS" in
    Fedora)
        systemctl stop firewalld
    ;;
    CentOS|RedHat)
        if [ "$(facter operatingsystemrelease | cut -d '.' -f1)" -lt "7" ]; then
            service iptables stop
        else
            systemctl stop firewalld
        fi
    ;;
    *)
        # nothing to do
    ;;
esac

# vim: ts=4 ts=4 sts=4 et :
