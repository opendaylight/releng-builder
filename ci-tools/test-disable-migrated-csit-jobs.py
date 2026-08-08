#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 The Linux Foundation
"""Self-check for disable-migrated-csit-jobs.py.

The tool edits JJB in place, so the property that matters is that it never
disables a job which cannot run on GitHub-hosted runners. Losing one of those
silently removes coverage instead of migrating it.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "dis", Path(__file__).with_name("disable-migrated-csit-jobs.py")
)
dis = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dis)

# Two blocks in one file with different timeouts -- the shape of
# jjb/netconf/netconf-scale.yaml, which is why the guard is per block.
MIXED = """---
- project:
    name: netconf-csit-scale
    jobs:
      - inttest-csit-1node
    project: "netconf"
    functionality: "scale"
    stream: vanadium

- project:
    name: netconf-csit-scale-max-devices
    jobs:
      - inttest-csit-1node
    project: "netconf"
    functionality: "scale-max-devices"
    stream: vanadium
    build-timeout: "720"
"""


def check(cond: bool, label: str) -> None:
    """Assert and report, so a failure names the property that broke."""
    assert cond, f"FAIL: {label}"
    print(f"ok: {label}")


def main() -> int:
    """Run the checks."""
    out, n, kept = dis.disable(MIXED)

    check(n == 1, "the 360m block is disabled")
    check(kept == 1, "the 720m block is kept")

    scale, maxdev = out.split("- project:\n")[1], out.split("- project:\n")[2]
    check("disable-job: true" in scale, "disable-job lands in the scale block")
    check(
        "disable-job: true" not in maxdev,
        "disable-job never lands in the over-ceiling block",
    )
    check(
        '"scale-max-devices"' in maxdev and 'build-timeout: "720"' in maxdev,
        "the kept block is passed through untouched",
    )

    # Idempotent: a second pass must not double-disable or resurrect the kept
    # block, since the migration runs wave by wave over the same files.
    again, n2, kept2 = dis.disable(out)
    check((n2, kept2) == (0, 1), "re-running disables nothing new")
    check(again == out, "re-running is a no-op")

    # A block at or under the ceiling migrates; only strictly above stays.
    check(not dis.stays_on_jenkins('build-timeout: "360"\n'), "360 migrates")
    check(dis.stays_on_jenkins('build-timeout: "361"\n'), "361 stays")
    check(not dis.stays_on_jenkins("no timeout here\n"), "absent inherits 360")

    restored, r, _ = dis.revert(out)
    check(r == 1, "revert re-enables exactly what was disabled")
    check(restored == MIXED, "revert round-trips to the original file")

    print("\nPASS: disable-migrated-csit-jobs never disables an over-ceiling job")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
