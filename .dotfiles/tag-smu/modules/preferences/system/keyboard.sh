#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "$HOME/set-me-up/.dotfiles/utilities/utils.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "   Keyboard\n\n"

execute "defaults write -g AppleKeyboardUIMode -int 3" \
    "Enable full keyboard access for all controls"

execute "defaults write -g ApplePressAndHoldEnabled -bool false" \
    "Disable press-and-hold in favor of key repeat"

execute "defaults write -g 'InitialKeyRepeat_Level_Saved' -int 10" \
    "Set delay until repeat"

execute "defaults write -g KeyRepeat -int 1 \
        && defaults write NSGlobalDomain InitialKeyRepeat -int 10" \
    "Set the key repeat rate to fast"

execute "defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false" \
    "Disable automatic capitalization"

execute "defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false" \
    "Disable automatic correction"

execute "defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false" \
    "Disable automatic period substitution"

execute "defaults write -g NSAutomaticDashSubstitutionEnabled -bool false" \
    "Disable smart dashes"

execute "defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false" \
    "Disable smart quotes"
