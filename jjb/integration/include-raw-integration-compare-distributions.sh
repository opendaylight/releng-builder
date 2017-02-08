#!/bin/bash

# Depends on variables created and published from the get-bundle-vars script

# Do not fail the build if there is trouble trying to collect distribution patch diffs
set +e

wget --progress=dot:mega $ACTUALBUNDLEURL
echo "Extracting the last distribution found on nexus..."
unzip -q $BUNDLE
mv $BUNDLEFOLDER /tmp/distro_old

echo "Extracting the distribution just created by this job..."
NEW_DISTRO=$(find $WORKSPACE -name distribution-karaf*.zip)
NEW_DISTRO_BASENAME=$(basename $NEW_DISTRO)
cp $NEW_DISTRO /tmp/
cd /tmp/
# the following extracts the .zip and learns the name of the folder extracted to
EXTRACTED_FOLDER=$(unzip $NEW_DISTRO_BASENAME | grep -m1 'creating:' | cut -d' ' -f5-)
mv $EXTRACTED_FOLDER distro_new

git clone https://git.opendaylight.org/gerrit/p/integration/test.git
cd test/tools/distchanges
mkdir -p $WORKSPACE/archives

python distcompare.py -r ssh://jenkins-$SILO@git.opendaylight.org:29418 | tee $WORKSPACE/archives/dist_diff.txt
# TODO: the output of the above command is not *friendly* for the reader because the most important info
# is listed last. This is fine/best for command line output, but for keeping in a file it would be better
# to put the summary at the beginning of the file. Some bash magic can be done here to make that happen.
