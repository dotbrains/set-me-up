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

    printf '{"mode":"%s","stage":"%s","candidate":{"ref":"%s","head":"%s","target":"%s","fresh":%s,"age_days":%s,"max_age_days":%s,"age_ok":%s},"release":{"tag":"%s","signed":%s,"github_release":%s},"publish_plan":[' \
        "$(smu_json_escape "${mode#--}")" "$(smu_json_escape "$stage")" \
        "$(smu_json_escape "$candidate_ref")" "$(smu_json_escape "$remote_candidate_head")" \
        "$(smu_json_escape "$installer_target_head")" "$fresh" "$age_days" \
        "$candidate_max_age_days" "$age_ok" "$(smu_json_escape "$release_tag")" \
        "$signed_tag" "$github_release"
    release_publish_plan_json
    printf '],"validated":%s,"pushed":%s,"tagged":%s,"failed":%s,"repositories":[' \
        "$validated" "$pushed" "$tagged" "$failed"
    release_repositories_json
    printf ']}\n'
    return 0
}
