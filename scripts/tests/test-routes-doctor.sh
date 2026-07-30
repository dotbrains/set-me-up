#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/test-helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-helpers.sh"

: "$repo_root" "$tmp_root"


test_route_lookup_finds_keyword_matches() {
    local work_dir="$tmp_root/route-lookup"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    (
        cd "$work_dir"
        bash scripts/route.sh theme > "$output"
    )

    assert_contains "$output" "modules-colorschemes"
    assert_contains "$output" "modules/colorschemes"
}

test_route_lookup_fails_without_matches() {
    local work_dir="$tmp_root/route-miss"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    if (
        cd "$work_dir"
        bash scripts/route.sh no-such-route > "$output" 2>&1
    ); then
        fail "route.sh succeeded without a matching route"
    fi

    assert_contains "$output" "No routes matched"
}

test_route_lookup_covers_core_concepts() {
    local work_dir="$tmp_root/route-coverage"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    (
        cd "$work_dir"
        bash scripts/route.sh smu > "$output"
        assert_contains "$output" "installer"

        bash scripts/route.sh prompt > "$output"
        assert_contains "$output" "home/.config/bash"

        bash scripts/route.sh claude > "$output"
        assert_contains "$output" "home/claude"

        bash scripts/route.sh codex > "$output"
        assert_contains "$output" "home/codex"

        bash scripts/route.sh macos > "$output"
        assert_contains "$output" "modules/macos"

        bash scripts/route.sh debian > "$output"
        assert_contains "$output" "modules/debian"

        bash scripts/route.sh nvim > "$output"
        assert_contains "$output" "home/.config/nvim"
    )
}

test_agent_intake_lists_intent_repositories() {
    local work_dir="$tmp_root/agent-intake-theme"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/modules/colorschemes/.git" \
        "$work_dir/installer/.git" "$work_dir/home/.config/alacritty/.git"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh theme > "$output"
    )

    assert_contains "$output" "path"
    assert_contains "$output" "modules/colorschemes"
    assert_contains "$output" "primary"
    assert_contains "$output" "installer"
    assert_contains "$output" "related"
    assert_contains "$output" "scripts/validate-repos.sh --changed"
}

test_agent_intake_json_reports_structured_plan() {
    local work_dir="$tmp_root/agent-intake-json"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/modules/colorschemes/.git" \
        "$work_dir/installer/.git"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --json theme > "$output"
    )

    assert_contains "$output" '"query":"theme"'
    assert_contains "$output" '"matchedIntents":["add-theme"'
    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"path":"modules/colorschemes"'
    assert_contains "$output" '"role":"primary"'
    assert_contains "$output" '"confidence":"high"'
    assert_contains "$output" '"score":'
    assert_contains "$output" '"source":"add-theme"'
    assert_contains "$output" '"explanation":"intent:add-theme'
    assert_contains "$output" '"warnings":['
    assert_contains "$output" '"nextCommands":['
    assert_contains "$output" '"scripts/validate.sh --coverage"'
}

test_agent_intake_falls_back_to_routes() {
    local work_dir="$tmp_root/agent-intake-route-fallback"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/modules/debian/.git"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh debian > "$output"
    )

    assert_contains "$output" "modules/debian"
    assert_contains "$output" "primary"
}

test_agent_intake_explain_outputs_reasons() {
    local work_dir="$tmp_root/agent-intake-explain"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/installer/.git"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --explain smu > "$output"
    )

    assert_contains "$output" "confidence"
    assert_contains "$output" "score"
    assert_contains "$output" "explain"
    assert_contains "$output" "intent:change-smu-command"
}

test_agent_intake_examples_keep_core_queries_stable() {
    local work_dir="$tmp_root/agent-intake-examples"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/modules/colorschemes/.git" \
        "$work_dir/installer/.git" "$work_dir/home/.config/zsh/.git" \
        "$work_dir/shared/ai-config/.git"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --json theme > "$output"
        assert_contains "$output" '"matchedIntents":["add-theme"'
        assert_contains "$output" '"path":"modules/colorschemes"'

        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --json prompt > "$output"
        assert_contains "$output" '"matchedIntents":["add-prompt"'
        assert_contains "$output" '"path":"installer"'

        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --json "agent config" > "$output"
        assert_contains "$output" '"matchedIntents":["agent-config"'
        assert_contains "$output" '"path":"shared/ai-config"'

        PATH="$bin_dir:$PATH" bash scripts/agent-intake.sh --json "new repo" > "$output"
        assert_contains "$output" '"matchedIntents":["add-managed-repo"'
        assert_contains "$output" '"path":"."'
    )
}

test_doctor_reports_repo_health_summary() {
    local work_dir="$tmp_root/doctor-summary"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git" "$work_dir/dirty/.git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
EOF
    cat > "$work_dir/scripts/agent-routes.txt" <<'EOF'
clean|clean|Clean repo|clean
dirty|dirty|Dirty repo|dirty
EOF
    printf "clean|custom validate\\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/doctor.sh > "$output"
    )

    assert_contains "$output" "set-me-up doctor"
    assert_contains "$output" "repos: total=3"
    assert_contains "$output" "dirty=1"
    assert_contains "$output" "missing=1"
    assert_contains "$output" "validators: present=1 missing=2"
    assert_contains "$output" "routes: present=2 missing=1"
}

test_doctor_verbose_reports_route_drift() {
    local work_dir="$tmp_root/doctor-route-drift"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    printf "bad|missing|Broken route|missing\\n" \
        > "$work_dir/scripts/agent-routes.txt"
    : > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/doctor.sh --verbose > "$output"
    )

    assert_contains "$output" "route-drift"
    assert_contains "$output" "routes: present=0 missing=1 drift=1"
}

test_doctor_json_reports_structured_summary() {
    local work_dir="$tmp_root/doctor-json"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"
    printf "clean|clean|Clean repo|clean\n" > "$work_dir/scripts/agent-routes.txt"
    printf "clean|custom validate\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/doctor.sh --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"summary":'
    assert_contains "$output" '"total":1'
}

test_health_report_schema_docs_exist() {
    local work_dir="$tmp_root/health-schema"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"
    printf "clean|clean|Clean repo|clean\n" > "$work_dir/scripts/agent-routes.txt"
    printf "clean|custom validate\n" > "$work_dir/scripts/repo-validators.txt"

    (
        cd "$work_dir"
        bash scripts/health-report.sh --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_file "$work_dir/scripts/schemas/health-report.schema.json"
    assert_file "$work_dir/scripts/schemas/health-report.example.json"
    assert_file "$work_dir/scripts/schemas/doctor.schema.json"
    assert_file "$work_dir/scripts/schemas/change-report.schema.json"
}

test_change_report_lists_recent_commits() {
    local work_dir="$tmp_root/change-report"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean"
    git -C "$work_dir/clean" init -q
    git -C "$work_dir/clean" config user.name "Test User"
    git -C "$work_dir/clean" config user.email "test@example.com"
    printf "hello\n" > "$work_dir/clean/README.md"
    git -C "$work_dir/clean" add README.md
    git -C "$work_dir/clean" -c commit.gpgsign=false commit -q -m "test commit"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"

    (
        cd "$work_dir"
        bash scripts/change-report.sh --since=1.day > "$output"
    )

    assert_contains "$output" "path"
    assert_contains "$output" "clean"
    assert_contains "$output" "test commit"
}

test_change_report_json_lists_recent_commits() {
    local work_dir="$tmp_root/change-report-json"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean"
    git -C "$work_dir/clean" init -q
    git -C "$work_dir/clean" config user.name "Test User"
    git -C "$work_dir/clean" config user.email "test@example.com"
    printf "hello\n" > "$work_dir/clean/README.md"
    git -C "$work_dir/clean" add README.md
    git -C "$work_dir/clean" -c commit.gpgsign=false commit -q -m "test commit"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"

    (
        cd "$work_dir"
        bash scripts/change-report.sh --since=1.day --json > "$output"
    )

    assert_contains "$output" '"commits":['
    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"subject":"test commit"'
}

test_freshness_report_json_lists_repositories() {
    local work_dir="$tmp_root/freshness-json"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean"
    git -C "$work_dir/clean" init -q
    git -C "$work_dir/clean" config user.name "Test User"
    git -C "$work_dir/clean" config user.email "test@example.com"
    printf "hello\n" > "$work_dir/clean/README.md"
    git -C "$work_dir/clean" add README.md
    git -C "$work_dir/clean" -c commit.gpgsign=false commit -q -m "test commit"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"

    (
        cd "$work_dir"
        bash scripts/freshness-report.sh --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"state":"fresh"'
}

test_capabilities_json_lists_routes() {
    local work_dir="$tmp_root/capabilities-json"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"
    printf "clean|clean|Clean repo|clean\n" > "$work_dir/scripts/agent-routes.txt"
    printf "clean|custom validate\n" > "$work_dir/scripts/repo-validators.txt"

    (
        cd "$work_dir"
        bash scripts/capabilities.sh --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"repo":"clean"'
    assert_contains "$output" '"route":"clean"'
}

test_sync_report_json_lists_repositories() {
    local work_dir="$tmp_root/sync-json"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git" "$work_dir/clean/.git"
    printf "clean|clean|top-level\n" > "$work_dir/scripts/repos.txt"
    printf "clean|custom validate\n" > "$work_dir/scripts/repo-validators.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/sync-report.sh --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"validator":"custom validate"'
}

test_json_schema_validation_runs() {
    local work_dir="$tmp_root/schema-validation"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"

    (
        cd "$work_dir"
        bash scripts/validate-json-schemas.sh > "$output"
    )

    assert_contains "$output" "JSON schema checks passed."
}



test_route_lookup_finds_keyword_matches
test_route_lookup_fails_without_matches
test_route_lookup_covers_core_concepts
test_agent_intake_lists_intent_repositories
test_agent_intake_json_reports_structured_plan
test_agent_intake_falls_back_to_routes
test_agent_intake_explain_outputs_reasons
test_agent_intake_examples_keep_core_queries_stable
test_doctor_reports_repo_health_summary
test_doctor_verbose_reports_route_drift
test_doctor_json_reports_structured_summary
test_health_report_schema_docs_exist
test_change_report_lists_recent_commits
test_change_report_json_lists_recent_commits
test_freshness_report_json_lists_repositories
test_capabilities_json_lists_routes
test_sync_report_json_lists_repositories
test_json_schema_validation_runs
