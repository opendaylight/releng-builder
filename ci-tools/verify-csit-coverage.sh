#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
##############################################################################
# Verify that every CSIT job JJB generates has a GitHub Actions counterpart.
#
# This is the migration safety net: while both systems run side by side, a JJB
# job that gains a stream or a functionality must not silently lack a GHA job.
# Regenerate with ci-tools/generate-csit-workflows.py and re-run this.
#
# Usage: ci-tools/verify-csit-coverage.sh [jjb-xml-dir]
#   With no argument the JJB XML is generated into a temporary directory.
##############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XML_DIR="${1:-}"

# shellcheck disable=SC2329  # invoked via trap
cleanup() {
    [ -n "${TMP_XML:-}" ] && rm -rf "$TMP_XML"
    rm -f "$EXPECTED" "$ACTUAL"
}
trap cleanup EXIT

EXPECTED="$(mktemp)"
ACTUAL="$(mktemp)"

if [ -z "$XML_DIR" ]; then
    command -v jenkins-jobs >/dev/null 2>&1 || {
        echo "ERROR: jenkins-jobs not found; pass a pre-generated XML dir" >&2
        exit 1
    }
    TMP_XML="$(mktemp -d)"
    XML_DIR="$TMP_XML"
    echo "---> expanding JJB into ${XML_DIR}"
    jenkins-jobs test -r "${REPO_ROOT}/jjb" -o "$XML_DIR" >/dev/null
fi

# What JJB says should exist.
python3 - "$XML_DIR" > "$EXPECTED" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

FINGERPRINT = ("TESTPLAN", "VM_0_COUNT", "CONTROLLERSCOPE")

for f in sorted(Path(sys.argv[1]).iterdir()):
    if not f.is_file():
        continue
    text = f.read_text(errors="replace")
    if "DISTROSTREAM" not in text:
        continue
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        continue
    names = {
        p.findtext("name")
        for p in root.iter()
        if p.tag.rsplit("}", 1)[-1].endswith("ParameterDefinition")
    }
    if all(k in names for k in FINGERPRINT):
        print(f.name)
PY

# What GHA actually covers.
jq -r '.[].job' "${REPO_ROOT}/.github/csit/csit-jobs.json" \
    | sort > "$ACTUAL"

sort -o "$EXPECTED" "$EXPECTED"

echo "---> JJB CSIT jobs:  $(wc -l < "$EXPECTED")"
echo "---> GHA CSIT jobs:  $(wc -l < "$ACTUAL")"

# Gerrit patch-verify jobs run from the verify pipeline, not a nightly matrix.
missing="$(comm -23 "$EXPECTED" "$ACTUAL" | grep -v -- '-csit-verify-' || true)"
extra="$(comm -13 "$EXPECTED" "$ACTUAL" || true)"

rc=0
if [ -n "$missing" ]; then
    echo "ERROR: JJB jobs with no GHA counterpart:" >&2
    echo "${missing//^/}" | while read -r j; do echo "  $j" >&2; done
    rc=1
fi
if [ -n "$extra" ]; then
    echo "ERROR: GHA jobs with no JJB counterpart:" >&2
    echo "${extra//^/}" | while read -r j; do echo "  $j" >&2; done
    rc=1
fi

[ "$rc" -eq 0 ] && echo "---> OK: CSIT coverage matches"
exit "$rc"
