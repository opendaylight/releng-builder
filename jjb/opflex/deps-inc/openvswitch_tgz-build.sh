#!/bin/bash
# Build script for openvswitch

set -e
set -x

if [[ $OPENVSWITCH_BUILD =~ v1 ]]; then
    refs="origin/noiro"
else
    refs="refs/tags/v2.6.0"
fi

git clone https://github.com/noironetworks/ovs.git
cd ovs || exit 1
git checkout "$refs"

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR"

./boot.sh
./configure --prefix="$ROOT" --enable-shared
make -j4
DESTDIR=`pwd`/$DESTDIR make install

if [[ $OPENVSWITCH_BUILD =~ v2 ]]; then
    # OVS headers get installed to weird and inconsistent locations.  Try
    # to clean things up
    mkdir -p $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openvswitch/*.h $DESTDIR/$ROOT/include/openvswitch/openvswitch
    mv $DESTDIR/$ROOT/include/openflow $DESTDIR/$ROOT/include/openvswitch
    cp -t "$DESTDIR/$ROOT/include/openvswitch/" include/*.h
fi

find lib -name "*.h" -exec cp --parents -t "$DESTDIR/$ROOT/include/openvswitch/" {} \;

pushd $DESTDIR
tar -czf openvswitch.tgz *
mv openvswitch.tgz "$WORKSPACE"
popd
