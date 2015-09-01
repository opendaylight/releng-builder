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
    puppet module install lex-dnsmasq -v 2.6.1

    # write the subdomain information into a custom facter fact
    mkdir -p /etc/facter/facts.d/
    echo "subdomain=${SUBDOM}" > /etc/facter/facts.d/subdomain.txt

    # final bits
    puppet apply /vagrant/confignetwork.pp

}

rh_systems_init() {
    # for some reason not all systems have @base installed
    yum install -y -q @base

    # also make sure that a few other utilities are definitely installed
    yum install -y -q unzip xz

    # install some needed internal networking configurations
    yum install -y dnsmasq puppet

    # remove current networking configurations
    rm -f /etc/sysconfig/network-scripts/{ifcfg,route}-{eth,docker}*
}

rh_systems_post() {
    # don't let cloud-init do funny things to our routing
    chattr +i /etc/sysconfig/network-scripts/route-eth0

    # setup the needed routing
    cat <<EOL >> /etc/rc.d/post-cloud-init
#!/bin/bash

# always force puppet to rerun
/usr/bin/puppet apply /vagrant/confignetwork.pp
EOL

    chmod +x /etc/rc.d/post-cloud-init

    # so that the network stack doesn't futz with our resolv config
    # after we've configured it
    chattr +i /etc/resolv.conf
}

ubuntu_systems_post() {
    # don't let cloud-init destroy our routing
#    chattr +i /etc/network/if-up.d/0000routing
    echo "---> do nothing for now"
}

systemd_init() {
    # create a post-cloud-init.service and enable it
    cat <<EOL > /etc/systemd/system/post-cloud-init.service
[Unit]
Description=Post cloud-init script (overwrites some cloud-init config)
After=cloud-init-local.service
Requires=cloud-init-local.service

[Service]
Type=oneshot
ExecStart=/etc/rc.d/post-cloud-init
TimeoutSec=0
#RemainAfterExit=yes
#SysVStartPriority=99

# Output needs to appear in instance console output
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOL

    /usr/bin/systemctl enable post-cloud-init.service
    chattr +i /etc/systemd/system/post-cloud-init.service
}

sysv_init() {
    # create the SysV init and enable it
    cat <<EOL > /etc/init.d/post-cloud-init
#!/bin/bash

### BEGIN INIT INFO
# Provides:         post-cloud-init
# Required-Start:   $local_fs $network $named $remote_fs cloud-init-local
# Should-Start:     $time
# Required-Stop:
# Should-Stop:
# Default-Start:    2 3 4 5
# Default-Stop:     0 1 6
# Short-Description:    Setup dnsmasq for LF Rackspace environment
# Description:      Setup dnsmasq for LF Rackspace environment after
#   cloud-init-local

# Return values acc. to LSB for all commands but status:
# 0       - success
# 1       - generic or unspecified error
# 2       - invalid or excess argument(s)
# 3       - unimplemented feature (e.g. "reload")
# 4       - user had insufficient privileges
# 5       - program is not installed
# 6       - program is not configured
# 7       - program is not running
# 8--199  - reserved (8--99 LSB, 100--149 distrib, 150--199 appl)
#
# Note that starting an already running service, stopping
# or restarting a not-running service as well as the restart
# with force-reload (in case signaling is not supported) are
# considered a success.

RETVAL=0

prog="post-cloud-init"

start() {
    echo -n $"Starting $prog: "
    /etc/rc.d/post-cloud-init
    RETVAL=$?
    return $RETVAL
}

stop() {
    echo -n $"Shutting down $prog:"
    # No-op
    RETVAL=7
    return $RETVAL
}

case "$1" in
    start)
        start
        RETVAL=$?
        ;;
    stop)
        stop
        RETVAL=$?
        ;;
    restart|try-restart|condrestart)
        start
        RETVAL=$?
        ;;
    status)
        echo -n $"Checking for service $prog: "
        # Return value is slightly different for the status command:
        # 0 - service up and running
        # 1 - service dead, but /var/run pid file exists
        # 2 - service dead, but /var/lock file exists
        # 3 - service not running (unused)
        # 4 - service status unknown :-(
        # 5--199 reserved (5-99 LSB, 100-149 distro, 150-199 appl.)
        RETVAL=4
        ;;
    *)
        echo "Usage: $0 {start|stop|status|try-restart|condrestart|restart|force-reload|reload}"
        RETVAL=3
        ;;
esac

exit $RETVAL
EOL
    chmod +x /etc/init.d/post-cloud-init

    /sbin/chkconfig --add post-cloud-init
    /sbin/chkconfig post-cloud-init on
}

# Execute setup that all systems need
all_systems

echo "---> Checking distribution"
FACTER_OSFAMILY=`/usr/bin/facter osfamily`
FACTER_OS=`/usr/bin/facter operatingsystem`
case "$FACTER_OSFAMILY" in
    RedHat)
        rh_systems_init
        case "$FACTER_OS" in
            Fedora)
                echo "---> Fedora found"
                systemd_init
            ;;
            RedHat|CentOS)
                if [ `/usr/bin/facter operatingsystemrelease | /bin/cut -d '.' -f1` = "7" ]; then
                    echo "---> CentOS 7"
                    systemd_init
                else
                    echo "---> CentOS 6"
                    sysv_init
                fi
            ;;
            *)
                echo "---> Unknown RH Family OS: ${FACTER_OS}"
            ;;
        esac
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
