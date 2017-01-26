#!/bin/bash
starting_marker={starting-marker}
ending_marker={ending-marker}
file_with_changes_to_insert={file-with-changes-to-insert}
file_to_change={file-to-change}
output=$(sed -e "/$starting_marker/,/$ending_marker/{{ /$starting_marker/{{p; r ${{file_with_changes_to_insert}}
        }}; /$ending_marker/p; d }}"  ${{file_to_change}})
echo "$output" > ${{file_to_change}}
