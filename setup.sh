#!/usr/bin/env bash

set -e

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git and try again."
    exit 1
fi

echo "Setting up set-me-up directory structure..."

# Helper function to clone repositories
clone_repo() {
    local url="$1"
    local path="$2"
    
    if [ -d "$path" ]; then
        echo "  ✓ $path already exists, skipping..."
        return 0
    fi
    
    echo "  → Cloning into $path..."
    git clone --recursive "$url" "$path"
}

# Create base directories
mkdir -p modules home/.config

# create .gitkeep file in home directory to prevent the directory from being deleted
touch home/.gitkeep
echo "home sweet ~/" > home/.gitkeep

# Clone top-level repositories
echo "Cloning top-level repositories..."
clone_repo "https://github.com/dotbrains/set-me-up-blueprint.git" "blueprint"
clone_repo "https://github.com/dotbrains/set-me-up-docs" "docs"
clone_repo "https://github.com/dotbrains/set-me-up-installer.git" "installer"
clone_repo "https://github.com/dotbrains/utilities.git" "utilities"

# Clone module repositories
echo "Cloning module repositories..."
clone_repo "https://github.com/dotbrains/colorschemes.git" "modules/colorschemes"
clone_repo "https://github.com/dotbrains/macports-module.git" "modules/macports"
clone_repo "https://github.com/dotbrains/preferences-module.git" "modules/preferences"
clone_repo "https://github.com/dotbrains/template-module.git" "modules/template-module"
clone_repo "https://github.com/dotbrains/set-me-up-universal-modules.git" "modules/universal"
clone_repo "https://github.com/dotbrains/xcode-module.git" "modules/xcode"

# Clone config repositories
echo "Cloning config repositories..."
clone_repo "https://github.com/dotbrains/alacritty.git" "home/.config/alacritty"
clone_repo "https://github.com/dotbrains/bash.git" "home/.config/bash"
clone_repo "https://github.com/dotbrains/fish.git" "home/.config/fish"
clone_repo "https://github.com/dotbrains/nushell.git" "home/.config/nushell"
clone_repo "https://github.com/dotbrains/nvim.git" "home/.config/nvim"
clone_repo "https://github.com/dotbrains/tmux.git" "home/.config/tmux"
clone_repo "https://github.com/dotbrains/zsh.git" "home/.config/zsh"

echo "✓ Setup complete! All repositories have been cloned."
