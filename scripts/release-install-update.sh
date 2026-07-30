#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="--check"
json_output=false
release_tag="${SMU_RELEASE_TAG:-}"
candidate_ref="${SMU_CANDIDATE_REF:-candidate}"

usage() {
    printf "Usage: %s [--check|--push] [--json] [--tag TAG] [--candidate REF]\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check | --push)
            mode="$1"
            ;;
        --json)
            json_output=true
            ;;
        --tag)
            shift
            release_tag="${1:-}"
            ;;
        --tag=*)
            release_tag="${1#*=}"
            ;;
        --candidate)
            shift
            candidate_ref="${1:-}"
            ;;
        --candidate=*)
            candidate_ref="${1#*=}"
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

json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf "%s" "$value"
}

repo_branch_head() {
    local path="$1"

    git -C "$repo_root/$path" rev-parse --abbrev-ref HEAD
}

repo_head() {
    local path="$1"

    git -C "$repo_root/$path" rev-parse HEAD
}

repo_sync() {
    local path="$1"

    if git -C "$repo_root/$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        local left_right
        left_right="$(git -C "$repo_root/$path" rev-list --left-right --count HEAD...'@{u}')"
        case "$left_right" in
            "0	0") printf "synced" ;;
            0$'\t'*) printf "behind" ;;
            *$'\t'0) printf "ahead" ;;
            *) printf "diverged" ;;
        esac
    else
        printf "unknown"
    fi
}

status_json() {
    local failed="$1"
    local validated="$2"
    local pushed="$3"
    local tagged="$4"

    printf '{"mode":"%s","candidate":{"ref":"%s"},"release":{"tag":"%s"},"validated":%s,"pushed":%s,"tagged":%s,"failed":%s,"repositories":[' \
        "$(json_escape "${mode#--}")" "$(json_escape "$candidate_ref")" "$(json_escape "$release_tag")" \
        "$validated" "$pushed" "$tagged" "$failed"
    local first=true
    local path branch clean sync head
    for path in installer blueprint tests; do
        branch="$(repo_branch_head "$path")"
        head="$(repo_head "$path")"
        sync="$(repo_sync "$path")"
        clean=true
        [ -n "$(git -C "$repo_root/$path" status --porcelain)" ] && clean=false
        if [ "$first" = true ]; then
            first=false
        else
            printf ','
        fi
        printf '{"path":"%s","branch":"%s","head":"%s","clean":%s,"sync":"%s"}' \
            "$(json_escape "$path")" "$(json_escape "$branch")" "$(json_escape "$head")" \
            "$clean" "$(json_escape "$sync")"
    done
    printf ']}\n'
}

validate_repo() {
    local path="$1"
    local command="$2"

    [ "$json_output" = true ] || printf "validate\t%s\t%s\n" "$path" "$command"
    (cd "$repo_root/$path" && eval "$command")
}

require_clean_repo() {
    local path="$1"

    if [ -n "$(git -C "$repo_root/$path" status --porcelain)" ]; then
        printf "Dirty repository: %s\n" "$path" >&2
        git -C "$repo_root/$path" status --short >&2
        return 1
    fi
}

push_repo() {
    local path="$1"
    local branch="$2"

    [ "$json_output" = true ] || printf "push\t%s\t%s\n" "$path" "$branch"
    git -C "$repo_root/$path" push origin "$branch"
}

tag_installer_release() {
    if [ "$mode" != "--push" ] || [ -z "$release_tag" ]; then
        return 0
    fi

    if git -C "$repo_root/installer" rev-parse "$release_tag" >/dev/null 2>&1; then
        [ "$json_output" = true ] || printf "tag\tinstaller\t%s\talready-exists\n" "$release_tag"
    else
        [ "$json_output" = true ] || printf "tag\tinstaller\t%s\n" "$release_tag"
        git -C "$repo_root/installer" tag -a "$release_tag" -m "Release $release_tag"
    fi

    git -C "$repo_root/installer" push origin "$release_tag"
}

update_candidate_ref() {
    if [ "$mode" != "--push" ]; then
        return 0
    fi
    if [ -z "$candidate_ref" ]; then
        return 0
    fi

    [ "$json_output" = true ] || printf "candidate\tinstaller\t%s\n" "$candidate_ref"
    git -C "$repo_root/installer" push origin "HEAD:refs/heads/$candidate_ref"
}

validate_repo "installer" "scripts/validate.sh --all"
validate_repo "blueprint" "scripts/validate.sh"
validate_repo "tests" "scripts/validate.sh"

require_clean_repo "installer"
require_clean_repo "blueprint"
require_clean_repo "tests"

if [ "$mode" = "--push" ]; then
    push_repo "installer" "main"
    push_repo "blueprint" "master"
    push_repo "tests" "main"
    update_candidate_ref
fi

tag_installer_release

if [ "$json_output" = true ]; then
    tagged=false
    [ -n "$release_tag" ] && tagged=true
    pushed=false
    [ "$mode" = "--push" ] && pushed=true
    status_json 0 true "$pushed" "$tagged"
else
    printf "release install/update %s complete\n" "${mode#--}"
    [ -n "$release_tag" ] && printf "release tag\t%s\n" "$release_tag"
    [ "$mode" = "--push" ] && [ -n "$candidate_ref" ] && printf "candidate ref\t%s\n" "$candidate_ref"
fi
