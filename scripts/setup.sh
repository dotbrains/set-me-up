#!/usr/bin/env bash

set -e

# Constants
readonly GITHUB_ORG="https://github.com/dotbrains"
readonly REPO_NAME="set-me-up"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPOS_FILE="$SCRIPT_DIR/repos.txt"

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
    if [ -f "README.md" ] && git rev-parse --git-dir &> /dev/null; then
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

cd "$REPO_ROOT"
ensure_setup_root
echo "📂 Working in: $(pwd)"
echo ""

# Clone a repository if it doesn't exist
clone_repo() {
    local repo="$1"
    local path="$2"
    
    if [ -d "$REPO_ROOT/$path" ]; then
        echo "  ✅ $path already exists, skipping..."
        return 0
    fi
    
    echo "  ⬇️  Cloning into $path..."
    git clone --recursive "${GITHUB_ORG}/${repo}.git" "$REPO_ROOT/$path" 2>&1 | sed 's/^/     /'
    echo "  ✨ Done: $path"
}

# Clone repositories by category
clone_category() {
    local category="$1"
    local icon="$2"
    local count=0
    
    echo "${icon} Cloning ${category} repositories..."
    echo ""
    
    while IFS='|' read -r repo path cat; do
        # Skip comments and empty lines
        [[ "$repo" =~ ^#.*$ || -z "$repo" ]] && continue
        
        if [ "$cat" = "$category" ]; then
            clone_repo "$repo" "$path"
            ((count++))
        fi
    done < "$REPOS_FILE"
    
    if [ $count -eq 0 ]; then
        echo "  ℹ️  No repositories to clone in this category"
    fi
    
    echo ""
}

# Create base directories in repo root
mkdir -p "$REPO_ROOT/modules" "$REPO_ROOT/home/.config"
touch "$REPO_ROOT/home/.gitkeep"
echo "home sweet ~/" > "$REPO_ROOT/home/.gitkeep"

# Check if repos.txt exists
if [ ! -f "$REPOS_FILE" ]; then
    echo "❌ Error: $REPOS_FILE not found. Please ensure it exists in the current directory."
    exit 1
fi

# Clone all repository categories
clone_category "top-level" "📦"
clone_category "module" "🧩"
clone_category "config" "⚙️"

echo "🎉 Setup complete! All repositories have been cloned."
echo ""
