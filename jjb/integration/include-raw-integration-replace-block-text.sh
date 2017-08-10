#!/bin/bash

starting_regex="$STARTING_REGEX"
ending_regex="$ENDING_REGEX"
file_with_changes_to_insert="$FILE_WITH_CHANGES_TO_INSERT"
file_to_change="$FILE_TO_CHANGE"
# shellcheck disable=SC2154
output=$(sed -e "/$starting_regex/,/$ending_regex/{{ /$starting_regex/{{p; r ${{file_with_changes_to_insert}}
        }}; /$ending_regex/p; d }}"  ${{file_to_change}})
echo "$output" > ${{file_to_change}}
