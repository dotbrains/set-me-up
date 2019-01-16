#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "$HOME/set-me-up/.dotfiles/utilities/utilities.sh"
    
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

print_in_purple "   Terminal\n\n"

execute "defaults write com.apple.terminal FocusFollowsMouse -string true" \
    "Make the focus automatically follow the mouse"

execute "defaults write com.apple.terminal SecureKeyboardEntry -bool true" \
    "Enable 'Secure Keyboard Entry'"

execute "defaults write com.apple.Terminal ShowLineMarks -int 0" \
    "Hide line marks"

execute "defaults write com.apple.terminal StringEncodings -array 4" \
    "Only use UTF-8"

execute "defaults write com.googlecode.iterm2 PromptOnQuit -bool false" \
    "Don’t display the annoying prompt when quitting iTerm"

execute "./set_terminal_theme.applescript" \
    "Set custom terminal theme"

# Ensure the Touch ID is used when `sudo` is required.

if ! grep -q "pam_tid.so" "/etc/pam.d/sudo"; then
    execute \
        "sudo sh -c 'echo \"auth sufficient pam_tid.so\" >> /etc/pam.d/sudo'" \
        "Use Touch ID to authenticate sudo"
fi
