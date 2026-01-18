#!/usr/bin/env bash

set -e

# Constants
readonly GITHUB_ORG="https://github.com/dotbrains"
readonly REPO_NAME="set-me-up"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed. Please install git and try again."
    exit 1
fi

echo ""
echo "🚀 Setting up set-me-up directory structure..."
echo ""

# Ensure we're in the set-me-up root directory
ensure_setup_root() {
    # Already in the repo?
    if [ -f "setup.sh" ] && [ -f "README.md" ] && git rev-parse --git-dir &> /dev/null; then
        echo "✅ Detected existing $REPO_NAME repository"
        return 0
    fi
    
    # Need to clone or enter directory
    if [ ! -d "$REPO_NAME" ]; then
        echo "📦 Cloning $REPO_NAME repository..."
        git clone "${GITHUB_ORG}/${REPO_NAME}.git" "$REPO_NAME"
        echo "✨ Repository cloned successfully"
    fi
    
    cd "$REPO_NAME"
}

ensure_setup_root
echo "📂 Working in: $(pwd)"
echo ""

# Clone a repository if it doesn't exist
clone_repo() {
    local repo="$1"
    local path="$2"
    
    if [ -d "$path" ]; then
        echo "  ✅ $path already exists, skipping..."
        return 0
    fi
    
    echo "  ⬇️  Cloning into $path..."
    git clone --recursive "${GITHUB_ORG}/${repo}.git" "$path" 2>&1 | sed 's/^/     /'
    echo "  ✨ Done: $path"
}

# Clone a batch of repositories
clone_batch() {
    local category="$1"
    local icon="$2"
    shift 2
    
    echo "${icon} Cloning ${category} repositories..."
    echo ""
    
    while [ $# -gt 0 ]; do
        clone_repo "$1" "$2"
        shift 2
    done
    
    echo ""
}

# Create base directories
mkdir -p modules home/.config
touch home/.gitkeep
echo "home sweet ~/" > home/.gitkeep

# Clone all repositories
clone_batch "top-level" "📦" \
    "set-me-up-blueprint" "blueprint" \
    "set-me-up-docs" "docs" \
    "set-me-up-installer" "installer" \
    "utilities" "utilities"

clone_batch "module" "🧩" \
    "colorschemes" "modules/colorschemes" \
    "macports-module" "modules/macports" \
    "preferences-module" "modules/preferences" \
    "template-module" "modules/template-module" \
    "set-me-up-universal-modules" "modules/universal" \
    "xcode-module" "modules/xcode"

clone_batch "config" "⚙️" \
    "alacritty" "home/.config/alacritty" \
    "bash" "home/.config/bash" \
    "fish" "home/.config/fish" \
    "nushell" "home/.config/nushell" \
    "nvim" "home/.config/nvim" \
    "tmux" "home/.config/tmux" \
    "zsh" "home/.config/zsh"

echo "🎉 Setup complete! All repositories have been cloned."
echo ""
