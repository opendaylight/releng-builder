#!/bin/bash

set -e

echo "---> Cleaning up OVS $OVS_VERSION"
docker logs $CID > $WORKSPACE/docker-ovs-${OVS_VERSION}.log
docker stop $CID
docker rm $CID
rm env.properties

docker images
