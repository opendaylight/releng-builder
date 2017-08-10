#!/bin/bash
# shellcheck disable=SC1083

starting_regex={starting-regex}
ending_regex={ending-regex}
# shellcheck disable=SC2034
file_with_changes_to_insert={file-with-changes-to-insert}
# shellcheck disable=SC2034
file_to_change={file-to-change}
# shellcheck disable=SC2154
output=$(sed -e "/$starting_regex/,/$ending_regex/{{ /$starting_regex/{{p; r ${{file_with_changes_to_insert}}
        }}; /$ending_regex/p; d }}"  ${{file_to_change}})
echo "$output" > ${{file_to_change}}
