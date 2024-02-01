#!/bin/bash
#The following script runs any configurable postplan stored in test/csit/postplans.
if [ -f "${WORKSPACE}/test/csit/postplans/${TESTPLAN}" ]; then
    echo "postplan exists!!!"
    echo "Changing the postplan path..."
    script_name=${WORKSPACE}/test/csit/postplans/${TESTPLAN}
    # shellcheck disable=SC2002
    cat "${script_name}" | sed "s:integration:${WORKSPACE}:" > postplan.txt
    cat postplan.txt
    grep -Ev '(^[[:space:]]*#|^[[:space:]]*$)' postplan.txt | while read -r line ; do
        echo "Executing ${line}..."
        ${line}
    done
fi
