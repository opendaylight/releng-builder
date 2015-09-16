#!/bin/bash

# script requires information about subdomain
if [ -z "$1" ]; then
    >&2 echo "Please provide the subdomain to Vagrant"
    exit 1
else
    SUBDOM=$1
fi


all_systems() {
    # install specific versions of puppet modules
    puppet module install puppetlabs-stdlib -v 4.5.1
    puppet module install puppetlabs-concat -v 1.2.0
    #puppet module install lex-dnsmasq -v 2.6.1
    puppet module install saz-dnsmasq -v 1.2.0

    # write the subdomain information into a custom facter fact
    mkdir -p /etc/facter/facts.d/
    echo "subdomain=${SUBDOM}" > /etc/facter/facts.d/subdomain.txt

    # final bits
    puppet apply /vagrant/lf-networking/confignetwork.pp

}

rh_systems_init() {
    # remove current networking configurations
    rm -f /etc/sysconfig/network-scripts/ifcfg-eth*
}

rh_systems_post() {
    # don't let cloud-init do funny things to our routing
    chattr +i /etc/sysconfig/network-scripts/route-eth0

    # so that the network stack doesn't futz with our resolv config
    # after we've configured it
#    chattr +i /etc/resolv.conf
}

ubuntu_systems_post() {
    # don't let cloud-init destroy our routing
#    chattr +i /etc/network/if-up.d/0000routing
    echo "---> do nothing for now"
}

# Execute setup that all systems need
all_systems

echo "---> Checking distribution"
FACTER_OSFAMILY=`/usr/bin/facter osfamily`
FACTER_OS=`/usr/bin/facter operatingsystem`
case "$FACTER_OSFAMILY" in
    RedHat)
        rh_systems_init
        rh_systems_post
    ;;
    Debian)
        case "$FACTER_OS" in
            Ubuntu)
                echo "---> Ubuntu found"
                ubuntu_systems_post
            ;;
            *)
                "---> Nothing to do for ${FACTER_OS}"
            ;;
        esac
    ;;
    *)
        echo "---> Unknown OS: ${FACTER_OSFAMILY}"
    ;;
esac

# vim: sw=4 ts=4 sts=4 et :
