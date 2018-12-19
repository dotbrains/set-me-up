#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    . "$(readlink -f "${current_dir}/../utilities/utils.sh")"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "\n   Firefox\n\n"

execute "defaults write org.mozilla.firefox AppleEnableSwipeNavigateWithScrolls -bool false" \
    "Disable backswipe"

killall "firefox" &> /dev/null
