
# Obtain current pom.xml for karaf-3.0.x branch of org.apache.karaf/karaf
wget "https://git-wip-us.apache.org/repos/asf?p=karaf.git;a=blob_plain;f=pom.xml;hb=refs/heads/karaf-3.0.x" -O "pom.xml"
# Extract the SNAPSHOTKARAFVERSION from the pom.xml
SNAPSHOTKARAFVERSION=`xpath pom.xml '/project/version/text()' 2> /dev/null`
echo "Snapshot Karaf version is ${SNAPSHOTKARAFVERSION}"

cat > ${WORKSPACE}/karaf_vars.txt <<EOF
SNAPSHOTKARAFVERSION=${SNAPSHOTKARAFVERSION}
EOF

# vim: ts=4 sw=4 sts=4 et ft=sh :
