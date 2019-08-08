#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 Red Hat, Inc. and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################

echo "Executing run-reports.sh"
set -e -o pipefail # Fail on errors, give stacktrace
set -x # Enable trace

virtualenv --quiet "/tmp/v/odltools"
# shellcheck disable=SC1091
source /tmp/v/odltools/bin/activate
pip install odltools
mkdir "$REPORT_PATH"
python -m odltools csit reports --numjobs "$NUM_JOBS" --path "$REPORT_PATH" --url "$LOG_URL" --jobnames "$JOB_NAMES" || true
python -m odltools csit exceptions --numjobs "$NUM_JOBS" --path "$REPORT_PATH" --url "$LOG_URL" --jobnames "$JOB_NAMES" || true
mkdir -p "$WORKSPACE/archives"
cp "$REPORT_PATH"/*.txt "$WORKSPACE/archives" || true
exit 0
