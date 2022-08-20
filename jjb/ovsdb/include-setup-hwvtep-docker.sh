#!/bin/sh

set -e

echo "---> Configuring OVS for HW VTEP Emulator"
/usr/bin/docker exec "$CID" supervisorctl stop ovsdb-server
/usr/bin/docker exec "$CID" supervisorctl start ovsdb-server-vtep
/usr/bin/docker exec "$CID" ovs-vsctl add-br br-vtep
/usr/bin/docker exec "$CID" ovs-vsctl add-port br-vtep eth0
/usr/bin/docker exec "$CID" vtep-ctl add-ps br-vtep
/usr/bin/docker exec "$CID" vtep-ctl add-port br-vtep eth0
/usr/bin/docker exec "$CID" vtep-ctl set Physical_Switch br-vtep tunnel_ips=192.168.254.20
/usr/bin/docker exec "$CID" vtep-ctl set-manager ptcp:6640
sleep 5
echo "---> Starting OVS HW VTEP Emulator"
/usr/bin/docker exec "$CID" supervisorctl start ovs-vtep
sleep 5
