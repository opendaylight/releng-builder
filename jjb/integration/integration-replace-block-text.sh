#!/bin/bash
starting_regex={starting-regex}
ending_regex={ending-regex}
file_with_changes_to_insert={file-with-changes-to-insert}
file_to_change={file-to-change}
output=$(sed -e "/$starting_regex/,/$ending_regex/{{ /$starting_regex/{{p; r ${{file_with_changes_to_insert}}
        }}; /$ending_regex/p; d }}"  ${{file_to_change}})
echo "$output" > ${{file_to_change}}
