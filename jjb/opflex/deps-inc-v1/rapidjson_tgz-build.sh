#!/bin/bash
# Build script for rapidjson

set -e
set -x

set -x

if [[ $RAPIDJSON_BUILD =~ v1 ]]; then
    version="1.0.1"
else
    version="1.0.2"
fi


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
tar -cvzf "rapidjson-$version.tar.gz" *
# Move tarball to dir of files that will be uploaded to Nexus
UPLOAD_FILES_PATH="$WORKSPACE/upload_files"
mkdir -p "$UPLOAD_FILES_PATH"
mv *.tar.gz "$_"
popd
