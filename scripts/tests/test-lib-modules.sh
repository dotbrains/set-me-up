#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp_root="${SMU_TEST_TMP_ROOT:-$(mktemp -d)}"

cleanup() {
    if [ -z "${SMU_TEST_KEEP_TMP:-}" ]; then
        rm -rf "$tmp_root"
    fi
}

if [ -z "${SMU_TEST_TMP_ROOT:-}" ]; then
    trap cleanup EXIT
fi

fail() {
    printf "FAIL: %s\n" "$1" >&2
    exit 1
}

assert_contains() {
    local file="$1"
    local pattern="$2"

    grep -Fq "$pattern" "$file" || {
        printf "Expected pattern not found: %s\n" "$pattern" >&2
        cat "$file" >&2
        exit 1
    }
}

test_manifest_index_validates_maps() {
    local work_dir="$tmp_root/manifest-index"

    mkdir -p "$work_dir"
    cat > "$work_dir/repos.txt" <<'EOF'
root|.|top-level
zsh|home/.config/zsh|config
EOF
    cat > "$work_dir/routes.txt" <<'EOF'
root|.|Root orchestration|root,setup
zsh|home/.config/zsh|Zsh config|zsh,shell
EOF
    cat > "$work_dir/intents.txt" <<'EOF'
add-theme|home/.config/zsh|.|scripts/validate-repos.sh --changed|Theme work|theme
add-prompt|home/.config/zsh|.|scripts/validate-repos.sh --changed|Prompt work|prompt
change-smu-command|.|home/.config/zsh|scripts/validate.sh --all|SMU work|smu
add-managed-repo|.|home/.config/zsh|scripts/validate.sh --all|Repo work|repo
add-module|.|home/.config/zsh|scripts/validate.sh --all|Module work|module
agent-config|.|home/.config/zsh|scripts/validate.sh --all|Agent work|agent
EOF
    cat > "$work_dir/validators.txt" <<'EOF'
home/.config/zsh|scripts/validate.sh --all
EOF

    (
        source "$repo_root/scripts/lib/repos.sh"
        source "$repo_root/scripts/lib/manifest-index.sh"
        smu_validate_repos_manifest "$work_dir/repos.txt"
        smu_validate_route_map "$work_dir/repos.txt" "$work_dir/routes.txt"
        smu_validate_intent_map "$work_dir/repos.txt" "$work_dir/intents.txt"
        smu_validate_repo_validators "$work_dir/repos.txt" "$work_dir/validators.txt"
        [ "$(smu_repo_name_for_path "$work_dir/repos.txt" home/.config/zsh)" = "zsh" ]
        [ "$(smu_route_drift_count "$work_dir/repos.txt" "$work_dir/routes.txt")" = "0" ]
    )
}

test_manifest_index_rejects_unknown_route_path() {
    local work_dir="$tmp_root/manifest-index-bad-route"
    local output="$work_dir/output"

    mkdir -p "$work_dir"
    printf "root|.|top-level\n" > "$work_dir/repos.txt"
    printf "bad|missing/path|Bad route|bad\n" > "$work_dir/routes.txt"

    if (
        source "$repo_root/scripts/lib/manifest-index.sh"
        smu_validate_route_map "$work_dir/repos.txt" "$work_dir/routes.txt"
    ) > "$output" 2>&1; then
        fail "manifest index accepted an unknown route path"
    fi
    assert_contains "$output" "is not in scripts/repos.txt"
}

test_check_runner_captures_failure_output() {
    local work_dir="$tmp_root/check-runner"
    local output="$work_dir/output"

    mkdir -p "$work_dir"
    if (
        source "$repo_root/scripts/lib/check-runner.sh"
        smu_check_runner_init 0
        smu_run_timed_check "failing check" bash -c 'printf "hidden detail\n"; exit 7'
    ) > "$output" 2>&1; then
        fail "check runner accepted a failing command"
    fi
    assert_contains "$output" "checking failing check"
    assert_contains "$output" "failing check: failed with exit 7"
    assert_contains "$output" "hidden detail"
}

test_repo_health_git_facts() {
    local work_dir="$tmp_root/repo-health"
    local repo="$work_dir/repo"

    mkdir -p "$repo"
    git -C "$repo" init --quiet --initial-branch main
    git -C "$repo" config user.name "set-me-up test"
    git -C "$repo" config user.email "set-me-up@example.test"
    printf "hello\n" > "$repo/README.md"
    git -C "$repo" add README.md
    git -C "$repo" commit --quiet -m "test fixture"

    (
        source "$repo_root/scripts/lib/repo-health.sh"
        [ "$(smu_repo_health_branch "$work_dir" repo)" = "main" ]
        [ "$(smu_repo_health_head "$work_dir" repo)" != "unknown" ]
        smu_repo_health_clean "$work_dir" repo
        [ "$(smu_repo_health_upstream_sync "$work_dir" repo)" = "unknown" ]
    )
}

test_manifest_index_validates_maps
test_manifest_index_rejects_unknown_route_path
test_check_runner_captures_failure_output
test_repo_health_git_facts
