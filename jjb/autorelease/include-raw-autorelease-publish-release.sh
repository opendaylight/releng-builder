#!/bin/bash

release_staging() {
	#FIXME:use param for nexus credentials
	curl -u admin:contextream -H "Accept: application/json" -H "Content-Type: application/json" -d "{\"data\":{\"stagedRepositoryIds\":["$STAGING_REPO_ID"],\"description\":\"Releasing $RELEASE_TAG.\"}}" $ODLNEXUS_STAGING_URL/service/local/staging/bulk/promote

}

clean_autorelease() {
	rm -fr publish
	rm -fr /tmp/patches
	mkdir publish
	pushd publish
	
	#FIXME:use param for gerrit user
	git clone -o cxtrm ssh://jenkins@cxtrm-gerrit:29418/releng/autorelease
}

download_patches() {
	cd /tmp
	wget ${LOGS_SERVER}/cxtrm/cxtrm-jenkins/autorelease-release-boron-downstream/$RELEASE_BUILD_NUMBER/archives/all-bundles.tar.gz
	tar -zxvf all-bundles.tar.gz --strip-components 3
	cd -
}

apply_patches() {
	for I in ${REPOS}; do
		cd $I
		echo apply patch for $I
		../scripts/patch-odl-release.sh "/tmp/patches" $RELEASE_TAG $RELEASE_BRANCH
		git review -y -t $RELEASE_TAG
		if [ "${DRY_RUN}X" == "X" ]; then
			git push cxtrm-gerrit release/$RELEASE_TAG
		fi
		cd -
	done
}

tag_autorelease() {
	git submodule foreach "git checkout release/$RELEASE_TAG"
	git add $REPOS
	git commit -m "Release $RELEASE_TAG"
	git tag -am "Opendaylight $RELEASE_TAG release" release/$RELEASE_TAG
	git review -y -t $RELEASE_TAG
	if [ "${DRY_RUN}X" == "X" ]; then
		git push cxtrm-gerrit release/$RELEASE_TAG
	fi
}


set -e

if [[ -z $STAGING_REPO_ID || -z $RELEASE_TAG || -z $RELEASE_BUILD_NUMBER || -z $RELEASE_BRANCH || -z $REPOS ]]; then
  echo 'one or more variables are undefined'
  exit 1
fi

echo "Release staging repo..."
release_staging
clean_autorelease
pushd  autorelease

echo "Checkout autorelease..."
git checkout -b $RELEASE_BRANCH remotes/cxtrm/$RELEASE_BRANCH
git submodule update --init --recursive --remote
git submodule foreach "git checkout $RELEASE_BRANCH"

echo "Download patches..."
download_patches

echo "Apply Patches..."
apply_patches

echo "Tag autorelease..."
tag_autorelease

set +e


