#!/bin/bash

# Make sure we have the leading space so multiple runs
# are idempotent
/bin/sed -i 's/ requiretty/ !requiretty/' /etc/sudoers;
