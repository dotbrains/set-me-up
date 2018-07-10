#!/bin/bash

install_latest_stable_ruby() {

    # Install the latest stable version of Ruby
    # (this will also set it as the default).

    # Determine which version is the LTS version of ruby
    # see: https://stackoverflow.com/a/30191850/5290011

    local latest_version

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    # Check if `rbenv` is installed

    if ! command -v "rbenv" &>/dev/null; then
        return 1
    fi

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    latest_version="$(
        . $HOME/.bashrc \
        && rbenv install -l | \
        grep -v - | \
        tail -1
    )"

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    . "$HOME/.bashrc" \
        && rbenv install "$latest_version" \
        && rbenv global "$latest_version"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

echo "------------------------------"
echo "Running ruby module"
echo "------------------------------"
echo ""

# Install `brew` dependencies

echo "------------------------------"
echo "Installing brew dependencies"

brew bundle install -v --file="./brewfile"

# Initialize `rbenv`

echo "------------------------------"
rbenv init

if [[ -z "${SMU_FISH_DIR+x}" ]]; then
    echo "It looks like you are not using the set-me-up terminal module."
    echo "Please follow the rbenv instructions above (generated by the command 'rbenv init') to complete the installation."
    read -n 1 -s -r -p "Press any key to continue."
    echo ""
fi

# Install the latest Ruby version using `rbenv`

echo "------------------------------"
echo "Installing the latest version of ruby"

install_latest_stable_ruby

rbenv rehash

# Install Ruby gems

echo "------------------------------"
echo "Installing ruby gems"

gem install \
bundler

rbenv rehash
