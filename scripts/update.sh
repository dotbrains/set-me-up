#!/usr/bin/env bash

set -e

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOS_FILE="$SCRIPT_DIR/repos.txt"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed. Please install git and try again."
    exit 1
fi

echo ""
echo "🔄 Updating set-me-up repositories..."
echo ""

# Check if repo has uncommitted changes
has_changes() {
    local path="$1"
    
    if [ ! -d "$path/.git" ]; then
        return 1
    fi
    
    cd "$path"
    
    # Check for uncommitted changes (modified, staged, untracked)
    if ! git diff-index --quiet HEAD -- 2>/dev/null || \
       [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
        cd - > /dev/null
        return 0
    fi
    
    cd - > /dev/null
    return 1
}

# Update a repository
update_repo() {
    local repo="$1"
    local path="$2"
    
    if [ ! -d "$path" ]; then
        echo "  ⏭️  $path doesn't exist, skipping..."
        return 0
    fi
    
    if ! [ -d "$path/.git" ]; then
        echo "  ⚠️  $path is not a git repository, skipping..."
        return 0
    fi
    
    if has_changes "$path"; then
        echo "  ⏭️  $path has uncommitted changes, skipping..."
        return 0
    fi
    
    echo "  ⬆️  Updating $path..."
    (
        cd "$path"
        git pull --rebase --recurse-submodules 2>&1 | sed 's/^/     /'
        if [ -f ".gitmodules" ]; then
            git submodule update --init --recursive 2>&1 | sed 's/^/     /'
        fi
    )
    echo "  ✨ Done: $path"
}

# Update repositories by category
update_category() {
    local category="$1"
    local icon="$2"
    local count=0
    
    echo "${icon} Updating ${category} repositories..."
    echo ""
    
    while IFS='|' read -r repo path cat; do
        # Skip comments and empty lines
        [[ "$repo" =~ ^#.*$ || -z "$repo" ]] && continue
        
        if [ "$cat" = "$category" ]; then
            update_repo "$repo" "$path"
            ((count++))
        fi
    done < "$REPOS_FILE"
    
    if [ $count -eq 0 ]; then
        echo "  ℹ️  No repositories to update in this category"
    fi
    
    echo ""
}

# Check if repos.txt exists
if [ ! -f "$REPOS_FILE" ]; then
    echo "❌ Error: $REPOS_FILE not found. Please ensure it exists in the current directory."
    exit 1
fi

# Update all repository categories
update_category "top-level" "📦"
update_category "module" "🧩"
update_category "config" "⚙️"

echo "🎉 Update complete! All repositories have been updated."
echo ""
