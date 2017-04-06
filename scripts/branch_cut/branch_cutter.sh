#!/bin/bash

while IFS="" read -r y; do
        ./br-cut7.awk "$y" > "$TEMP"
        [[ -s "$TEMP" ]] && mv "$TEMP" "$y"
    fi
done < <(find ./builder-test-brcut -name "*.yaml")
