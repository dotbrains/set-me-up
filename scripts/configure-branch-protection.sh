#!/usr/bin/env bash

set -euo pipefail

mode="${1:---plan}"
owner="${SMU_GITHUB_OWNER:-dotbrains}"
drift=0

usage() {
    printf "Usage: %s [--plan|--check|--apply]\n" "$0" >&2
}

case "$mode" in
    --plan | --check | --apply)
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
    local require_reviews="${4:-true}"

    if [ "$mode" = "--plan" ]; then
        printf "protect\t%s/%s\t%s\tcontexts=%s\n" \
            "$owner" "$repo" "$branch" "$contexts_json"
        return 0
    fi

    command -v gh >/dev/null 2>&1 || {
        printf "gh is required for %s\n" "$mode" >&2
        return 2
    }

    if [ "$mode" = "--check" ]; then
        local actual
        actual="$(
            gh api "/repos/$owner/$repo/branches/$branch/protection/required_status_checks" \
                --jq '.contexts | sort | @json' >/tmp/smu-branch-protection-contexts 2>/dev/null && \
                cat /tmp/smu-branch-protection-contexts || printf "__missing__"
        )"
        local expected
        expected="$(python3 - "$contexts_json" <<'PY'
import json
import sys

print(json.dumps(sorted(json.loads(sys.argv[1])), separators=(",", ":")))
PY
)"
        if [ "$actual" = "$expected" ]; then
            printf "ok\t%s/%s\t%s\tcontexts=%s\n" "$owner" "$repo" "$branch" "$expected"
        elif [ "$actual" = "__missing__" ]; then
            printf "missing\t%s/%s\t%s\texpected=%s\n" \
                "$owner" "$repo" "$branch" "$expected" >&2
            drift=1
        else
            printf "drift\t%s/%s\t%s\texpected=%s\tactual=%s\n" \
                "$owner" "$repo" "$branch" "$expected" "$actual" >&2
            drift=1
        fi
        return 0
    fi

    local reviews_json
    if [ "$require_reviews" = true ]; then
        reviews_json='{
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "require_last_push_approval": false
  }'
    else
        reviews_json="null"
    fi

    gh api --method PUT \
        "/repos/$owner/$repo/branches/$branch/protection" \
        --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": $contexts_json
  },
  "enforce_admins": false,
  "required_pull_request_reviews": $reviews_json,
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
protect_branch set-me-up-installer candidate '[]' false
protect_branch set-me-up-blueprint master '["CI"]'
protect_branch set-me-up-tests main '["CI / default-scenario"]'

[ "$drift" -eq 0 ]
