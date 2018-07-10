#!/bin/bash

echo "------------------------------"
echo "Running editor module"
echo "------------------------------"
echo ""

# Install `brew` dependencies

echo "------------------------------"
echo "Installing brew dependencies"

brew bundle install -v --file="./brewfile"

# Install SpaceVim

echo "------------------------------"
echo "Installing spacevim"

curl -sLf https://spacevim.org/install.sh | bash

# Configure Visual Studio Code

echo "------------------------------"
echo "Configuring Visual Studio Code"

if [[ $(command -v code) ]]; then
    code --install-extension CodeSync
fi

# Install Diff- and merge tools

echo "------------------------------"
echo "Installing diff- and merge tools"

# https://pempek.net/articles/2014/04/18/git-p4merge/
curl -fsSL https://pempek.net/files/git-p4merge/mac/p4merge > /usr/local/bin/p4merge
chmod +x /usr/local/bin/p4merge

# https://github.com/so-fancy/diff-so-fancy
git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
