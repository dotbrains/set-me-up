#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "$HOME/set-me-up/.dotfiles/utilities/utilities.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    # Install Nerd Fonts via Homebrew 
    # see: https://gist.github.com/davidteren/898f2dcccd42d9f8680ec69a3a5d350e

    brew_bundle_install -f "brewfile"

}

main