#!/bin/bash

# It looks like the devstack gate is stomping on our dnsmasq setup which
# therefore kills our ability to do proper lookups of some resources.
# Let's capture the 3 nexus IPs into /etc/hosts
cat <<EOHOSTS >> /etc/hosts
# the internal address for nexus
$(dig +short nexus.opendaylight.org) nexus.opendaylight.org
# all the nexus proxies
$(dig +short nexus01.dfw.opendaylight.org) nexus01.dfw.opendaylight.org
$(dig +short nexus02.dfw.opendaylight.org) nexus02.dfw.opendaylight.org
$(dig +short nexus03.ord.opendaylight.org) nexus03.ord.opendaylight.org
EOHOSTS

# make sure we don't require tty for sudo operations
cat <<EOF >/etc/sudoers.d/89-jenkins-user-defaults
Defaults:jenkins !requiretty
jenkins     ALL = NOPASSWD: ALL
EOF

# vim: sw=2 ts=2 sts=2 et :
