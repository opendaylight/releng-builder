#!/bin/bash -x

set +e  # To avoid failures in projects which generate zero snapshot artifacts.
find /tmp/r/org/opendaylight/$GERRIT_PROJECT/ -path *-SNAPSHOT* -delete
find /tmp/r/ -regex '.*/_remote.repositories\|.*/maven-metadata-local\.xml\|.*/maven-metadata-fake-nexus\.xml\|.*/resolver-status\.properties' -delete
find /tmp/r/ -type d -empty -delete
echo "# INFO: A listing of project related files left in local repository follows."
find /tmp/r/org/opendaylight/$GERRIT_PROJECT/
true  # To prevent the possibly non-zero return code from failing the job.
