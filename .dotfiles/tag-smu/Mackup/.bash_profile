#!/bin/bash

# shellcheck source=/dev/null

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source_bash_files() {

    declare CURRENT_DIRECTORY

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    CURRENT_DIRECTORY="$(pwd)"

    declare -r -a FILES_TO_SOURCE=(
        "bash_aliases"
        "bash_autocomplete"
        "bash_exports"
        "bash_functions"
        "bash_options"
        "bash_prompt"
        "keybindings"
        "bash.local"  # For local settings that should
                      # not be under version control.
    )

    local file=""
    local i=""

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    for i in ${!FILES_TO_SOURCE[*]}; do

        file="$HOME/.${FILES_TO_SOURCE[$i]}"

        [ -r "$file" ] \
            && . "$file"

    done

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    . "$DOTFILES/.dotfiles/utilities/utils.sh"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    cd "$CURRENT_DIRECTORY" || return

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

source_bash_files
unset -f source_bash_files

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'bash-sensible' configs.
# see: https://github.com/mrzool/bash-sensible

if [ -d "$HOME"/.config/bash-sensible ]; then
    . "$HOME"/.config/bash-sensible/sensible.bash
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'autoenv' configs.
# see: https://github.com/kennethreitz/autoenv

if [ -f "$(brew --prefix autoenv)"/activate.sh ]; then
    . "$(brew --prefix autoenv)"/activate.sh
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'autojump' configs.
# see: https://github.com/wting/autojump

if [ -f "/usr/local/etc/profile.d/autojump.sh" ]; then
    . /usr/local/etc/profile.d/autojump.sh
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'jump' configs.
# see: https://github.com/wting/autojump

if [ -f "$(brew --prefix jump)" ]; then
    eval "$(jump shell)"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'commacd' configs.
# see: https://github.com/shyiko/commacd

if [ -f "$HOME"/.commacd.bash ]; then
    . "$HOME"/.commacd.bash
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'aliasme' configs.
# see: https://github.com/Jintin/aliasme

if [ -f "$HOME"/.aliasme/aliasme.sh ]; then
    . "$HOME"/.aliasme/aliasme.sh
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# load 'fz' configs.
# see: https://github.com/changyuheng/fz#bash

if [ -d "$HOME"/.bash_completion.d ]; then
  for file in "$HOME"/.bash_completion.d/*; do
    . "$file"
  done
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Clear system messages (system copyright notice, the date
# and time of the last login, the message of the day, etc.)
# and changes directory to $HOME.

clear && cd "$HOME" || return

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Always start tmux on start-up of bash
# see: https://unix.stackexchange.com/a/219803/173825

if command -v tmux >/dev/null; then
        if [ -n "$PS1" ]; then # unless shell is not loaded interactively, run `tmux`
                [[ ! $TERM =~ screen ]] && [ -z "$TMUX" ] && tmux
        fi
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Start up fish shell

command -v fish &> /dev/null && fish

