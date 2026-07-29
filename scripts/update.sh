#!/usr/bin/env bash

set -euo pipefail

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly REPOS_FILE="$SCRIPT_DIR/repos.txt"

source "$SCRIPT_DIR/lib/repos.sh"

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
    
    local git_output
    local git_exit_code
    
    # Pull changes
    git_output=$(cd "$path" && git pull --rebase --recurse-submodules 2>&1)
    git_exit_code=$?
    
    if [ $git_exit_code -ne 0 ]; then
        echo "     ❌ Error updating $path:"
        printf "%s\n" "$git_output" | sed 's/^/        /'
        return 1
    fi
    printf "%s\n" "$git_output" | sed 's/^/     /'
    
    # Update submodules if they exist
    if [ -f "$path/.gitmodules" ]; then
        git_output=$(cd "$path" && git submodule update --init --recursive 2>&1)
        git_exit_code=$?
        
        if [ $git_exit_code -ne 0 ]; then
            echo "     ❌ Error updating submodules in $path:"
            printf "%s\n" "$git_output" | sed 's/^/        /'
            return 1
        fi
        printf "%s\n" "$git_output" | sed 's/^/     /'
    fi
    
    echo "  ✨ Done: $path"
    return 0
}

# Update repositories by category
update_category() {
    local category="$1"
    local icon
    local count=0
    local failed=0

    icon="$(smu_category_icon "$category")"
    echo "${icon} Updating ${category} repositories..."
    echo ""

    update_repo_for_category() {
        local repo="$1"
        local path="$2"

        if ! update_repo "$repo" "$path"; then
            ((failed++))
        fi
        ((count++))
    }

    smu_each_repo_in_category "$REPOS_FILE" "$category" update_repo_for_category
    
    if [ $count -eq 0 ]; then
        echo "  ℹ️  No repositories to update in this category"
    elif [ $failed -gt 0 ]; then
        echo "  ⚠️  $failed out of $count repositories failed to update"
    fi
    
    echo ""
    return $failed
}

# Check if repos.txt exists and is valid
if ! smu_validate_repos_manifest "$REPOS_FILE"; then
    echo "❌ Error: invalid repository manifest."
    exit 1
fi

# Update all repository categories
total_failed=0

for category in "${SMU_REPO_CATEGORIES[@]}"; do
    update_category "$category" || total_failed=$((total_failed + $?))
done

if [ $total_failed -gt 0 ]; then
    echo "⚠️  Update completed with errors. $total_failed repositories failed to update."
    echo ""
    exit 1
else
    echo "🎉 Update complete! All repositories have been updated."
    echo ""
fi
