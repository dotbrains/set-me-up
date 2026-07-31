#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

set -euo pipefail

release_publish_plan_json() {
    local first=true

    emit_action() {
        local action="$1"
        local target="$2"
        local detail="$3"

        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '{"action":"%s","target":"%s","detail":"%s"}' \
            "$(smu_json_escape "$action")" "$(smu_json_escape "$target")" \
            "$(smu_json_escape "$detail")"
    }

    emit_action "push" "installer" "main"
    emit_action "push" "blueprint" "master"
    emit_action "push" "tests" "main"
    [ -n "$candidate_ref" ] && emit_action "candidate" "installer" "$candidate_ref"
    [ -n "$release_tag" ] && emit_action "tag" "installer" "$release_tag"
    [ "$github_release" = true ] && \
        emit_action "github-release" "installer" "${release_tag:-<required-tag>}"
    return 0
}

release_repositories_json() {
    local first=true
    local path
    local branch
    local clean
    local sync
    local head

    for path in installer blueprint tests; do
        branch="missing"
        head="unknown"
        sync="missing"
        clean=false
        if [ -d "$repo_root/$path/.git" ]; then
            branch="$(repo_branch_head "$path")"
            head="$(repo_head "$path")"
            sync="$(repo_sync "$path")"
            smu_repo_health_clean "$repo_root" "$path" && clean=true || clean=false
        elif [ -d "$repo_root/$path" ]; then
            sync="not-git"
        fi
        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '{"path":"%s","branch":"%s","head":"%s","clean":%s,"sync":"%s"}' \
            "$(smu_json_escape "$path")" "$(smu_json_escape "$branch")" \
            "$(smu_json_escape "$head")" "$clean" "$(smu_json_escape "$sync")"
    done
}

release_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

release_workflow_url() {
    if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ] && \
        [ -n "${GITHUB_RUN_ID:-}" ]; then
        printf "%s/%s/actions/runs/%s" "$GITHUB_SERVER_URL" "$GITHUB_REPOSITORY" "$GITHUB_RUN_ID"
    fi
}

release_tag_head() {
    if [ -n "$release_tag" ] && git -C "$repo_root/installer" rev-parse "$release_tag^{commit}" >/dev/null 2>&1; then
        git -C "$repo_root/installer" rev-parse "$release_tag^{commit}"
    else
        printf "unknown"
    fi
}

release_provenance_json() {
    printf '"provenance":{"timestamp":"%s","workflow_run":"%s","installer":"%s","candidate":"%s","tag":"%s","blueprint":"%s","tests":"%s"}' \
        "$(smu_json_escape "$(release_timestamp)")" \
        "$(smu_json_escape "$(release_workflow_url)")" \
        "$(smu_json_escape "$(repo_head installer)")" \
        "$(smu_json_escape "$(candidate_head)")" \
        "$(smu_json_escape "$(release_tag_head)")" \
        "$(smu_json_escape "$(repo_head blueprint)")" \
        "$(smu_json_escape "$(repo_head tests)")"
}

release_status_json() {
    local failed="$1"
    local validated="$2"
    local pushed="$3"
    local tagged="$4"
    local stage="${5:-complete}"
    local installer_target_head
    local remote_candidate_head
    local fresh
    local age_days
    local age_ok

    installer_target_head="$(repo_head installer)"
    remote_candidate_head="$(candidate_head)"
    fresh="$(candidate_fresh "$installer_target_head" "$remote_candidate_head")"
    age_days="$(candidate_age_days "$remote_candidate_head")"
    age_ok="$(candidate_age_ok "$age_days")"

    printf '{"mode":"%s","stage":"%s","dry_run":%s,"candidate":{"ref":"%s","head":"%s","target":"%s","fresh":%s,"age_days":%s,"max_age_days":%s,"age_ok":%s},"release":{"tag":"%s","signed":%s,"github_release":%s,"notes_file":"%s"},"publish_plan":[' \
        "$(smu_json_escape "${mode#--}")" "$(smu_json_escape "$stage")" \
        "$dry_run" \
        "$(smu_json_escape "$candidate_ref")" "$(smu_json_escape "$remote_candidate_head")" \
        "$(smu_json_escape "$installer_target_head")" "$fresh" "$age_days" \
        "$candidate_max_age_days" "$age_ok" "$(smu_json_escape "$release_tag")" \
        "$signed_tag" "$github_release" "$(smu_json_escape "$release_notes_file")"
    release_publish_plan_json
    printf '],"validated":%s,"preflight_contracts":%s,"pushed":%s,"tagged":%s,"failed":%s,' \
        "$validated" "${preflight_contracts:-false}" "$pushed" "$tagged" "$failed"
    release_provenance_json
    printf ',"repositories":['
    release_repositories_json
    printf ']}\n'
    return 0
}
