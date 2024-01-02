#!/bin/bash

# shellcheck source=/dev/null

declare current_dir &&
    current_dir="$(dirname "${BASH_SOURCE[0]}")" &&
    cd "${current_dir}" &&
    source "$HOME/set-me-up/.dotfiles/utilities/utilities.sh"

readonly SMU_PATH="$HOME/set-me-up"

# Get the absolute path of the .dotfiles directory.
# This is only for aesthetic reasons to have an absolute symlink path instead of a relative one
# <path-to-smu>/.dotfiles/somedotfile vs <path-to-smu>/.dotfiles/base/../somedotfile
readonly dotfiles="${SMU_PATH}/.dotfiles"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

change_default_bash_version() {

    local PATH_TO_HOMEBREW_BASH=""

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Get the path of the `Bash` version installed through `Homebrew`.

    PATH_TO_HOMEBREW_BASH="$(brew --prefix)/bin/bash"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Add the path of the `Bash` version installed through `Homebrew`
    # to the list of login shells from the `/etc/shells` file.
    #
    # This needs to be done because applications use this file to
    # determine whether a shell is valid (e.g.: `chsh` consults the
    # `/etc/shells` to determine whether an unprivileged user may
    # change the login shell for their own account).
    #
    # http://www.linuxfromscratch.org/blfs/view/7.4/postlfs/etcshells.html

    if ! grep -q "$(tr <<<"$PATH_TO_HOMEBREW_BASH" '\n' '\01')" < <(less "/etc/shells" | tr '\n' '\01'); then
        printf '%s\n' "$PATH_TO_HOMEBREW_BASH" | sudo tee -a /etc/shells &>/dev/null
    fi

}

create_fish_local() {

    declare -r FILE_PATH="$HOME/.fish.local"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    if [[ ! -e "$FILE_PATH" ]] || [[ -z "$FILE_PATH" ]]; then
        touch "$FILE_PATH"
    fi

}

change_default_shell_to_fish() {

    local PATH_TO_FISH=""

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Get the path of `fish` which was installed through `Homebrew`.

    PATH_TO_FISH="$(brew --prefix)/bin/fish"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Add the path of the `fish` version installed through `Homebrew`
    # to the list of login shells from the `/etc/shells` file.
    #
    # This needs to be done because applications use this file to
    # determine whether a shell is valid (e.g.: `chsh` consults the
    # `/etc/shells` to determine whether an unprivileged user may
    # change the login shell for their own account).
    #
    # http://www.linuxfromscratch.org/blfs/view/7.4/postlfs/etcshells.html

    if ! grep -q "$(tr <<<"$PATH_TO_FISH" '\n' '\01')" < <(less "/etc/shells" | tr '\n' '\01'); then
        printf '%s\n' "$PATH_TO_FISH" | sudo tee -a /etc/shells &>/dev/null
    fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Set latest version of `fish` as the default shell

    if [[ "$(dscl . -read /Users/"${USER}"/ UserShell | cut -d ' ' -f2)" != "${PATH_TO_FISH}" ]]; then
        chsh -s "$PATH_TO_FISH" &>/dev/null
    fi

}

install_fisher() {

    if ! is_fisher_installed; then
        curl -Lo "$HOME"/.config/fish/functions/fisher.fish --create-dirs --silent https://git.io/fisher
    fi

}

install_fisher_packages() {

    if [ -f "$HOME/.config/fish/fish_plugins" ]; then
        cat <"$HOME/.config/fish/fish_plugins" | while read -r PACKAGE; do
            fisher_install "$PACKAGE"
        done
    else
        cat <"$dotfiles/tag-smu/config/fish/fish_plugins" | while read -r PACKAGE; do
            fisher_install "$PACKAGE"
        done
    fi

    fisher_update

}

symlink() {

    # Update and/or install dotfiles. These dotfiles are stored in the .dotfiles directory.
    # rcup is used to install files from the tag-specific dotfiles directory.
    # rcup is part of rcm, a management suite for dotfiles.
    # Check https://github.com/thoughtbot/rcm for more info.

    export RCRC="$dotfiles/rcrc" &&
        rcup -v -f -d "${dotfiles}"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    if is_debian; then
        apt_install_from_file "packages"
    fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    bash "${SMU_PATH}"/.dotfiles/modules/brew/brew.sh

    if command -v brew &>/dev/null; then
        if [[ -d "$(brew --prefix)/bin" ]]; then
            export PATH="$(brew --prefix)/bin:$PATH"
        fi

        if [[ -d "$(brew --prefix)/sbin" ]]; then
            export PATH="$(brew --prefix)/sbin:$PATH"
        fi
    fi

    brew_bundle_install -f "brewfile"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # if is_macos; then
    # No longer needed because zsh is now the default shell.
    # change_default_bash_version
    # fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # We must now symlink our dotfiles prior to executing any other function.
    # This is required because any further action will require our dotfiles
    # to be present in our $HOME directory.
    symlink

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    create_fish_local

    change_default_shell_to_fish

    install_fisher

    install_fisher_packages

    fish -c "printf \"y\n\" | fish_config theme save \"Nord\""

}

main
