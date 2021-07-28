#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "$HOME/set-me-up/.dotfiles/utilities/utilities.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    brew_bundle_install "brewfile"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Close any open `System Preferences` panes in order to
    # avoid overriding the preferences that are being changed.

    ./close_system_preferences_panes.applescript

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # App preferences
    ./apps/terminal/terminal.sh
	./apps/iTerm2/iterm2.sh
    ./apps/app_store.sh
    ./apps/finder.sh
    ./apps/chrome.sh
    ./apps/safari.sh
    ./apps/maps.sh
    ./apps/photos.sh
    ./apps/transmission.sh
    ./apps/textedit.sh
    ./apps/firefox.sh
    ./apps/alfred/alfred.sh

    # System preferences
    ./system/dashboard.sh
    ./system/dock.sh
    ./system/keyboard.sh
    ./system/language_and_region.sh
    ./system/ui_and_ux.sh
	./system/launchpad.sh

}

main
