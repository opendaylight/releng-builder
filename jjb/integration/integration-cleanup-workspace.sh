#!/bin/sh

echo "Cleaning up the workspace..."

# Leftover files from previous runs could be wrongly copied as results.
# Keep the cloned integration/test repository!
for file_or_dir in *
# FIXME: Make this compatible with multipatch and other possible build&run jobs.
do
    if [ "$file_or_dir" != "test" ]; then
        rm -vrf "$file_or_dir"
    fi
done
