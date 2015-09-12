#!/bin/bash
# @License EPL-1.0 <http://spdx.org/licenses/EPL-1.0>
##############################################################################
# Copyright (c) 2015 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

GIT_REPORT_FILE=$REPORT_DIR/git-report.log

mkdir $REPORT_DIR
touch $GIT_REPORT_FILE

projects=`grep path .gitmodules | sed 's/.*= //' | sort`
for p in $projects; do
    echo "" >> $GIT_REPORT_FILE
    echo "========" >> $GIT_REPORT_FILE
    echo "$p" >> $GIT_REPORT_FILE
    echo "========" >> $GIT_REPORT_FILE
    echo "" >> $GIT_REPORT_FILE

    cd $WORKSPACE/$p
    git log --after="1 week ago" >> $GIT_REPORT_FILE
    cd $WORKSPACE
done
