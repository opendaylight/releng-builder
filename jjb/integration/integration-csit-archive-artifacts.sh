#!/bin/bash

echo "Archiving csit artifacts"
cd "$WORKSPACE"
mkdir -p ./archives
for i in $(seq 1 ${NUM_ODL_SYSTEM}); do
    NODE_FOLDER="./archives/odl_${i}"
    mkdir -p "${NODE_FOLDER}"
    mv odl"${i}"_* "${NODE_FOLDER}" || true
    mv karaf_"${i}"_*_threads* "${NODE_FOLDER}" || true
    mv *_"${i}".png "${NODE_FOLDER}" || true
    mv /tmp/odl"${i}"_* "${NODE_FOLDER}" || true
    mv gclogs-"${i}" "${NODE_FOLDER}" || true
done
curl --output robot-plugin.zip "$BUILD_URL/robot/report/*zip*/robot-plugin.zip"
unzip -d ./archives robot-plugin.zip
mv '*.log' '*.log.gz' '*.csv' '*.png' ./archives || true  # Don't fail if file missing
# TODO: Can the following line ever fail?
find . -type f -name '*.hprof' -print0 \
    | tar -cvf - --null -T - | xz --threads=0 > ./archives/hprof.tar.xz
# TODO: Tweak the compression level if better ratio (or speed) is needed.
