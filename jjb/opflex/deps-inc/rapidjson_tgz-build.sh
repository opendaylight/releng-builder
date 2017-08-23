#!/bin/bash
# Build script for rapidjson

set -e
set -x

if [[ $RAPIDJSON_BUILD =~ v1 ]]; then
    refs="refs/tags/v1.0.1"
else
    refs="refs/tags/v1.0.2"
fi

git clone https://github.com/miloyip/rapidjson.git
cd rapidjson || exit 1
git checkout "$refs"

ROOT=/tmp/opflex-prefix
DESTDIR=install-root

mkdir -p "$DESTDIR/$ROOT/lib/pkgconfig"
mkdir -p "$DESTDIR/$ROOT/include"

cp -R include/rapidjson "$DESTDIR/$ROOT/include"
sed -e "s|@INCLUDE_INSTALL_DIR@|$ROOT/include|" \
    -e "s|@PROJECT_NAME@|RapidJSON|" \
    -e "s|@LIB_VERSION_STRING@|1.0.2|" RapidJSON.pc.in > \
    "$DESTDIR/$ROOT/lib/pkgconfig/RapidJSON.pc"

pushd $DESTDIR
tar -czf rapidjson.tgz *
mv rapidjson.tgz "$WORKSPACE"
popd
