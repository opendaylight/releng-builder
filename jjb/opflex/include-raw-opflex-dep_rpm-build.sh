#!/bin/bash

set -e
set -x

LIBUV_VERSION=1.5.0
wget https://github.com/libuv/libuv/archive/v$LIBUV_VERSION.tar.gz
mock --define="buildversion $BUILD_NUMBER" -r $MOCK_TARGET --resultdir target/srpm --buildsrpm --spec libuv.spec --sources v$LIBUV_VERSION.tar.gz

RAPIDJSON_VERSION=1.0.2
wget https://github.com/miloyip/rapidjson/archive/v$RAPIDJSON_VERSION.tar.gz
mock --define="buildversion $BUILD_NUMBER" -r $TARGET --resultdir target/srpm --buildsrpm --spec rapidjson-devel.spec --sources v$RAPIDJSON_VERSION.tar.gz

mockchain -m --define="buildversion $BUILD_NUMBER" -r $MOCK_TARGET -l target/rpm target/srpm/*.src.rpm
find target/rpm/results -name "*.rpm" -exec mv {} . \;
