#!/usr/bin/env bash

set -euo pipefail

# Constants
readonly GITHUB_ORG="https://github.com/dotbrains"
readonly REPO_NAME="set-me-up"
REPO_ROOT=""
REPOS_FILE=""

usage() {
    printf "Usage: %s\n" "$0" >&2
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage
        exit 2
        ;;
esac

is_setup_root() {
    local path="$1"

    [ -f "$path/README.md" ] && \
        [ -f "$path/scripts/repos.txt" ] && \
        git -C "$path" rev-parse --git-dir &> /dev/null
}

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed. Please install git and try again."
    exit 1
fi

echo ""
echo "🚀 Setting up set-me-up directory structure..."
echo ""

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    script_repo_root="$(cd "$script_dir/.." && pwd)"

    if is_setup_root "$script_repo_root"; then
        cd "$script_repo_root"
    fi
fi

# Ensure we're in the set-me-up root directory
ensure_setup_root() {
    # Already in the repo?
    if is_setup_root "."; then
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
REPO_ROOT="$(pwd)"
REPOS_FILE="$REPO_ROOT/scripts/repos.txt"
source "$REPO_ROOT/scripts/lib/repos.sh"
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
    local icon
    local count=0

    icon="$(smu_category_icon "$category")"
    echo "${icon} Cloning ${category} repositories..."
    echo ""

    clone_repo_for_category() {
        local repo="$1"
        local path="$2"

        clone_repo "$repo" "$path"
        ((count++)) || true
    }

    smu_each_repo_in_category "$REPOS_FILE" "$category" clone_repo_for_category
    
    if [ $count -eq 0 ]; then
        echo "  ℹ️  No repositories to clone in this category"
    fi
    
    echo ""
}

# Create base directories in repo root
mkdir -p "$REPO_ROOT/modules" "$REPO_ROOT/home/.config" "$REPO_ROOT/shared"
touch "$REPO_ROOT/home/.gitkeep"
echo "home sweet ~/" > "$REPO_ROOT/home/.gitkeep"

# Check if repos.txt exists and is valid
if ! smu_validate_repos_manifest "$REPOS_FILE"; then
    echo "❌ Error: invalid repository manifest."
    exit 1
fi

# Clone all repository categories
for category in "${SMU_REPO_CATEGORIES[@]}"; do
    clone_category "$category"
done

echo "🎉 Setup complete! All repositories have been cloned."
echo ""
