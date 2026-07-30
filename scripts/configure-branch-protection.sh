#!/usr/bin/env bash

set -euo pipefail

mode="${1:---plan}"
owner="${SMU_GITHUB_OWNER:-dotbrains}"

usage() {
    printf "Usage: %s [--plan|--apply]\n" "$0" >&2
}

case "$mode" in
    --plan | --apply)
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

protect_branch() {
    local repo="$1"
    local branch="$2"
    local contexts_json="$3"

    if [ "$mode" = "--plan" ]; then
        printf "protect\t%s/%s\t%s\tcontexts=%s\n" \
            "$owner" "$repo" "$branch" "$contexts_json"
        return 0
    fi

    command -v gh >/dev/null 2>&1 || {
        printf "gh is required for --apply\n" >&2
        return 2
    }

    gh api --method PUT \
        "/repos/$owner/$repo/branches/$branch/protection" \
        --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": $contexts_json
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": true
}
JSON
}

protect_branch set-me-up master '["Tests / Test on ubuntu-latest","Tests / Test on macos-latest","Release Readiness / Install/update release readiness"]'
protect_branch set-me-up-installer main '["Tests"]'
protect_branch set-me-up-installer candidate '[]'
protect_branch set-me-up-blueprint master '["CI"]'
protect_branch set-me-up-tests main '["CI / default-scenario"]'
