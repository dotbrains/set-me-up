#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "../utilities/utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Maps\n\n"

execute "defaults write com.apple.Maps LastClosedWindowViewOptions '{
            localizeLabels = 1;   // show labels in English
            mapType = 11;         // show hybrid map
            trafficEnabled = 0;   // do not show traffic
         }'" \
    "Set view options"

killall "Maps" &> /dev/null
