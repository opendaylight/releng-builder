#!/bin/bash

set -e

OVS_VERSION=${OVS_VERSION:-2.5.0}

echo "---> Cleaning up existing Docker processes and images"
for x in $(docker ps -a -q)
do
   docker stop "$x"
   docker rm "$x"
done

for x in $(docker images | grep vpickard | awk '{print $3}')
do
   docker rmi "$x"
done



echo "---> Starting OVS $OVS_VERSION"
/usr/bin/docker pull vpickard/openvswitch:$OVS_VERSION
CID=$(/usr/bin/docker run -p 6641:6640 --privileged=true -d -i -t vpickard/openvswitch:$OVS_VERSION /usr/bin/supervisord)
REALCID=`echo $CID | rev | cut -d ' ' -f 1 | rev`
echo "CID=$REALCID" > env.properties
echo "OVS_VERSION=${OVS_VERSION}" >> env.properties
CONTROLLER_IP=`facter ipaddress`
echo "CONTROLLER_IP=${CONTROLLER_IP}" >> env.properties

echo "---> Waiting..."
sleep 10
