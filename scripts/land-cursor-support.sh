#!/usr/bin/env bash

set -euo pipefail

# Land Cursor agent support across set-me-up child repositories.
# Requires GitHub credentials with push access to smeltery/* repos.
#
# Usage:
#   scripts/land-cursor-support.sh
#   scripts/land-cursor-support.sh --create-prs
#   scripts/land-cursor-support.sh --merge

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
branch="cursor/cursor-agent-support"
create_prs=0
merge_prs=0

usage() {
    printf "Usage: %s [--create-prs] [--merge]\\n" "$0" >&2
    printf "  --create-prs  Open PRs after pushing branches\\n" >&2
    printf "  --merge       Merge PRs after creation (needs review bypass or approval)\\n" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --create-prs)
            create_prs=1
            ;;
        --merge)
            merge_prs=1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
    shift
done

require_clean_push() {
    local label="$1"
    local path="$2"

    if [ ! -d "$path/.git" ]; then
        printf "Missing checkout: %s (run ./scripts/setup.sh)\\n" "$path" >&2
        exit 1
    fi

    cd "$path"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        printf "Dirty checkout blocks landing: %s\\n" "$label" >&2
        exit 1
    fi
}

push_branch() {
    local label="$1"
    local path="$2"
    local remote_repo="$3"

    cd "$path"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git checkout "$branch"
    else
        printf "Branch %s missing in %s — apply changes first.\\n" "$branch" "$label" >&2
        exit 1
    fi
    git push -u origin "$branch"
    printf "Pushed %s (%s)\\n" "$label" "$remote_repo"
}

open_pr() {
    local remote_repo="$1"
    local title="$2"
    local body="$3"

  gh pr create \
        --repo "$remote_repo" \
        --head "$branch" \
        --title "$title" \
        --body "$body" \
        || gh pr view --repo "$remote_repo" "$branch" --web
}

merge_pr() {
    local remote_repo="$1"
    gh pr merge --repo "$remote_repo" "$branch" --squash --delete-branch || true
}

printf "Landing Cursor agent support from %s\\n" "$repo_root"

require_clean_push "shared-ai-config" "$repo_root/shared/ai-config"
require_clean_push "universal-modules" "$repo_root/modules/universal"

if [ -d "$repo_root/home/cursor/.git" ]; then
    require_clean_push "cursor" "$repo_root/home/cursor"
fi

push_branch "shared-ai-config" "$repo_root/shared/ai-config" "smeltery/shared-ai-config"
push_branch "universal-modules" "$repo_root/modules/universal" "smeltery/set-me-up-universal-modules"

if [ -d "$repo_root/home/cursor/.git" ]; then
    if gh repo view smeltery/cursor >/dev/null 2>&1; then
        push_branch "cursor" "$repo_root/home/cursor" "smeltery/cursor"
    else
        printf "Creating smeltery/cursor and pushing main...\\n"
        cd "$repo_root/home/cursor"
        gh repo create smeltery/cursor --public \
            --description "Cursor agent configuration for set-me-up" \
            --source . \
            --remote origin \
            --push
    fi
fi

if [ "$create_prs" -eq 1 ]; then
    open_pr "smeltery/shared-ai-config" \
        "feat: add cursor tool to shared assemble workflow" \
        "Extend assemble.sh so cursor config repos compose agents and skills from shared bodies."

    open_pr "smeltery/set-me-up-universal-modules" \
        "feat: add cursor-cli universal module" \
        "Install Cursor agent CLI via the official curl installer and add ~/.local/bin to shell PATH."

    if gh repo view smeltery/cursor >/dev/null 2>&1 && \
        git -C "$repo_root/home/cursor" show-ref --verify --quiet "refs/heads/$branch"; then
        open_pr "smeltery/cursor" \
            "feat: initial Cursor agent configuration" \
            "Initial Cursor agent config with assembled agents and ship skill."
    fi
fi

if [ "$merge_prs" -eq 1 ]; then
    merge_pr "smeltery/shared-ai-config"
    merge_pr "smeltery/set-me-up-universal-modules"
    if gh repo view smeltery/cursor >/dev/null 2>&1; then
        merge_pr "smeltery/cursor"
    fi
fi

printf "Done. Root set-me-up PR: https://github.com/smeltery/set-me-up/pull/5\\n"
