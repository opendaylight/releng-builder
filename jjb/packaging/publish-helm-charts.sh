#!/bin/sh -l
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2021 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
echo "---> publish-help-charts.sh"

set -e -o pipefail
echo "*** starting releace process for $BUILD_TYPE"
ls -l
pwd
cd "$WORKSPACE/helm/opendaylight" || exit
helm_charts=$(find "$WORKSPACE/helm/opendaylight")

for chart in $helm_charts; do
  chart=$(echo "$chart" | xargs)
  echo " ** processing chart $chart"
  case "$BUILD_TYPE" in
    'snapshot')
      echo "  * snapshot build, pushing to https://nexus3.opendaylight.org/repository/packaging-helm-testing/"
      curl -vn --upload-file "$chart" "https://nexus3.opendaylight.org/repository/packaging-helm-testing/"
      ;;
    'staging')
      echo "  * staging build, pushing to https://nexus3.opendaylight.org/repository/packaging-helm-testing/"
      curl -vn --upload-file "$chart" "https://nexus3.opendaylight.org/repository/packaging-helm-testing/"
      ;;
    'release')
      echo "  * release build, pushing to https://nexus3.opendaylight.org/repository/packaging-helm-release/"
      curl -n --upload-file "$chart" "https://nexus3.opendaylight.org/repository/packaging-helm-release/"
        ;;
    *)
      echo "You must set BUILD_TYPE to one of (snapshot, staging, release)."
      exit 1
      ;;
  esac
done
echo "*** release process finished"
cd ../../../
