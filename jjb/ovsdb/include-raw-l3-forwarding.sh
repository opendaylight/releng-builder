#!/bin/bash

echo 'Enable l3 forwarding'
echo 'ovsdb.l3.fwd.enabled=yes' >> ${WORKSPACE}/target/assembly/etc/custom.properties
echo 'Add l3 gateway'
echo 'ovsdb.l3gateway.mac=00:00:5E:00:02:01' >> ${WORKSPACE}/target/assembly/etc/custom.properties
