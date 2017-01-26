#!/bin/bash

git clone https://git.opendaylight.org/gerrit/p/releng/builder ${WORKSPACE}/builder
cd ${WORKSPACE}/builder
start='csit-list-carbon: >'
finish='csit-list-boron: >'
output=$(sed -e "/$start/,/$finish/{ /$start/{p; r csit_jobs_carbon.lst
        }; /$finish/p; d }"  jjb/releng-defaults.yaml)
echo "$output" > jjb/releng-defaults.yaml

start='csit-list-boron: >'
finish='csit-list-beryllium: >'
output=$(sed -e "/$start/,/$finish/{ /$start/{p; r csit_jobs_boron.lst
        }; /$finish/p; d }"  jjb/releng-defaults.yaml)
echo "$output" > jjb/releng-defaults.yaml

start='csit-list-beryllium: >'
finish='# CSIT TESTS END SED MARKER'
output=$(sed -e "/$start/,/$finish/{ /$start/{p; r csit_jobs_beryllium.lst
        }; /$finish/p; d }"  jjb/releng-defaults.yaml)
echo "$output" > jjb/releng-defaults.yaml
