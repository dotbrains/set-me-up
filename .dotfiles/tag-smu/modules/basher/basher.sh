#!/bin/bash

# shellcheck source=/dev/null

declare current_dir && \
    current_dir="$(dirname "${BASH_SOURCE[0]}")" && \
    cd "${current_dir}" && \
    source "$HOME/set-me-up/.dotfiles/utilities/utils.sh"

readonly SMU_PATH="$HOME/set-me-up"

LOCAL_BASH_CONFIG_FILE="${SMU_PATH}/.dotfiles/tag-smu/bash.local"
LOCAL_FISH_CONFIG_FILE="${SMU_PATH}/.dotfiles/tag-smu/fish.local"

declare -r BASHER_DIRECTORY="$HOME/.basher"
declare -r BASHER_GIT_REPO_URL="https://github.com/basherpm/basher"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

install_basher() {

    execute \
        "git clone --quiet $BASHER_GIT_REPO_URL $BASHER_DIRECTORY" \
        "basher (install)" \
        && add_basher_configs

}

add_basher_configs() {

    # bash

    declare -r BASH_CONFIGS="
# basher - A package manager for shell scripts.
export PATH=\"$HOME/.basher/bin:\$PATH\"
eval \"\$(basher init -)\""

    execute \
        "printf '%s\n' '$BASH_CONFIGS' >> $LOCAL_BASH_CONFIG_FILE \
            && . $LOCAL_BASH_CONFIG_FILE" \
        "basher (update $LOCAL_BASH_CONFIG_FILE)"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # fish

    declare -r FISH_CONFIGS="
# Basher package manager configurations
# see: https://github.com/basherpm/basher
if type -q basher
    if test -d ~/.basher
        set basher ~/.basher/bin
    end
    set -gx PATH \$basher \$PATH
    status --is-interactive; and . (basher init -|psub)
end
"

    execute \
        "printf '%s\n' '$FISH_CONFIGS' >> $LOCAL_FISH_CONFIG_FILE" \
        "basher (update $LOCAL_FISH_CONFIG_FILE)"

}

basher_upgrade() {

     execute \
        "cd $BASHER_DIRECTORY \
            && git fetch --quiet origin" \
        "basher (upgrade)"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    print_in_purple "  Basher\n\n"

    if ! cmd_exists "basher"; then
        install_basher
    else
        basher_upgrade
    fi

}

main
