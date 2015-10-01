#!/bin/bash
# Build OVS RPMs

set -e
set -x

TARGET=epel-7-x86_64
BASEKERNEL=3.10.0-229.14.1.el7.x86_64
BVDEFINE=--define="buildversion $BUILD_NUMBER"
KMDEFINE=--define="kversion $BASEKERNEL"

./boot.sh
./configure
make dist

SOURCE_FILE=$(ls *.tar.gz)

mock -r $TARGET --resultdir target/srpm --buildsrpm --spec rhel/openvswitch-gbp-rhel.spec --sources $SOURCE_FILE "$BVDEFINE" "$KMDEFINE"
mock -r $TARGET --resultdir target/srpm --buildsrpm --spec rhel/openvswitch-gbp-kmod-rhel.spec --sources $SOURCE_FILE "$BVDEFINE" "$KMDEFINE"
mockchain -r $TARGET -l target/rpm -m --nocheck -m "$BVDEFINE" -m "$KMDEFINE" target/srpm/*.src.rpm

find target/rpm/results -name "*.rpm" -exec mv {} . \;
