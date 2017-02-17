#!/bin/bash

# Depends on variables created and published from the get-bundle-vars script

# Do not fail the build if there is trouble trying to collect distribution patch diffs
set +e

wget --progress=dot:mega $ACTUALBUNDLEURL
echo "Extracting the last distribution found on nexus..."
unzip -q $BUNDLE
mv $BUNDLEFOLDER /tmp/distro_old
rm $BUNDLE

echo "Extracting the distribution just created by this job..."
NEW_DISTRO=$(find $WORKSPACE -name distribution-karaf*.zip)
NEW_DISTRO_BASENAME=$(basename $NEW_DISTRO)
cp $NEW_DISTRO /tmp/
cd /tmp/
# get the name of the folder which will be extracted to
EXTRACTED_FOLDER=$(unzip $NEW_DISTRO_BASENAME | grep 'creating:' | grep -v '/.' | cut -d' ' -f5-)
mv $EXTRACTED_FOLDER distro_new

git clone https://git.opendaylight.org/gerrit/p/integration/test.git
cd test/tools/distchanges
mkdir -p $WORKSPACE/archives

# Full output of compare tool will be in temp file /tmp/dist_diff.txt
# The file/report to be archived will only list the distribution in the comparison and the patches that
# are different.
python distcompare.py -r ssh://jenkins-$SILO@git.opendaylight.org:29418 | tee /tmp/dist_diff.txt
echo -e "Patch differences listed are in comparison to:\n\t$ACTUALBUNDLEURL\n\n" > $WORKSPACE/archives/distribution_differences.txt
sed -ne '/Patch differences/,$ p' /tmp/dist_diff.txt >> $WORKSPACE/archives/distribution_differences.txt
