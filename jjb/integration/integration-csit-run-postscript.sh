#!/bin/bash
#The following script runs any configurable postplan stored in test/csit/postplans.
if [ -f "${WORKSPACE}/test/csit/postplans/${TESTPLAN}" ]; then
    echo "postplan exists!!!"
    echo "Changing the postplan path..."
    script_name=${WORKSPACE}/test/csit/postplans/${TESTPLAN}
    cat ${script_name} | sed "s:integration:${WORKSPACE}:" > postplan.txt
    cat postplan.txt
    egrep -v '(^[[:space:]]*#|^[[:space:]]*$)' postplan.txt | while read -r line ; do
        echo "Executing ${line}..."
        ${line}
    done
fi
