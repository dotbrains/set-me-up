#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/scripts/lib/repo-health.sh"
source "$repo_root/scripts/lib/json.sh"
source "$repo_root/scripts/lib/release-readiness-render.sh"
mode="--check"
json_output=false
release_tag="${SMU_RELEASE_TAG:-}"
candidate_ref="${SMU_CANDIDATE_REF:-candidate}"
candidate_max_age_days="${SMU_CANDIDATE_MAX_AGE_DAYS:-14}"
signed_tag=false
github_release=false
release_title="${SMU_RELEASE_TITLE:-}"
release_notes="${SMU_RELEASE_NOTES:-}"
current_stage="parse-arguments"

usage() {
    printf "Usage: %s [--check|--push|--publish-plan|--candidate-check|--self-test] [--json] [--tag TAG] [--candidate REF] [--signed-tag] [--github-release] [--release-title TITLE] [--release-notes NOTES]\n" "$0" >&2
}

on_exit() {
    local exit_code="$?"

    if [ "$exit_code" -ne 0 ] && [ "$json_output" = true ]; then
        release_status_json "$exit_code" false false false "$current_stage"
    fi
}
trap on_exit EXIT

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check | --push | --publish-plan | --candidate-check | --self-test)
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
        --signed-tag)
            signed_tag=true
            ;;
        --github-release)
            github_release=true
            ;;
        --release-title)
            shift
            release_title="${1:-}"
            ;;
        --release-title=*)
            release_title="${1#*=}"
            ;;
        --release-notes)
            shift
            release_notes="${1:-}"
            ;;
        --release-notes=*)
            release_notes="${1#*=}"
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

repo_branch_head() {
    smu_repo_health_branch "$repo_root" "$1"
}

repo_head() {
    smu_repo_health_head "$repo_root" "$1"
}

repo_sync() {
    smu_repo_health_upstream_sync "$repo_root" "$1"
}

remote_ref_head() {
    local path="$1"
    local ref="$2"

    git -C "$repo_root/$path" ls-remote origin "refs/heads/$ref" 2>/dev/null | \
        awk 'NR == 1 { print $1 }'
}

candidate_head() {
    local head

    head="$(remote_ref_head installer "$candidate_ref")"
    [ -n "$head" ] && printf "%s" "$head" || printf "unknown"
}

candidate_fresh() {
    local installer_head="$1"
    local remote_candidate_head="$2"

    [ -n "$candidate_ref" ] || {
        printf "true"
        return 0
    }
    [ "$remote_candidate_head" = "$installer_head" ] && printf "true" || printf "false"
}

candidate_age_days() {
    local remote_candidate_head="$1"
    local commit_time
    local now

    [ "$remote_candidate_head" != "unknown" ] || {
        printf "%s" "-1"
        return 0
    }
    if ! git -C "$repo_root/installer" cat-file -e "$remote_candidate_head^{commit}" 2>/dev/null; then
        git -C "$repo_root/installer" fetch --quiet origin "$remote_candidate_head" 2>/dev/null || true
    fi
    commit_time="$(git -C "$repo_root/installer" show -s --format=%ct "$remote_candidate_head" 2>/dev/null || printf "0")"
    [ "$commit_time" -gt 0 ] || {
        printf "%s" "-1"
        return 0
    }
    now="$(date +%s)"
    printf "%s" "$(((now - commit_time) / 86400))"
}

candidate_age_ok() {
    local age_days="$1"

    [ "$age_days" -ge 0 ] && [ "$age_days" -le "$candidate_max_age_days" ] && \
        printf "true" || printf "false"
}

validate_repo() {
    local path="$1"
    local command="$2"

    current_stage="validate:$path"
    [ "$json_output" = true ] || printf "validate\t%s\t%s\n" "$path" "$command"
    if [ "$json_output" = true ]; then
        (cd "$repo_root/$path" && eval "$command") >/dev/null 2>&1
    else
        (cd "$repo_root/$path" && eval "$command")
    fi
}

require_clean_repo() {
    local path="$1"

    current_stage="clean:$path"
    if [ -n "$(git -C "$repo_root/$path" status --porcelain)" ]; then
        if [ "$json_output" != true ]; then
            printf "Dirty repository: %s\n" "$path" >&2
            git -C "$repo_root/$path" status --short >&2
        fi
        return 1
    fi
}

push_repo() {
    local path="$1"
    local branch="$2"

    current_stage="push:$path"
    [ "$json_output" = true ] || printf "push\t%s\t%s\n" "$path" "$branch"
    if [ "$json_output" = true ]; then
        git -C "$repo_root/$path" push --quiet origin "$branch" >/dev/null 2>&1
    else
        git -C "$repo_root/$path" push origin "$branch"
    fi
}

tag_installer_release() {
    if [ "$mode" != "--push" ] || [ -z "$release_tag" ]; then
        return 0
    fi

    current_stage="tag:installer"
    if git -C "$repo_root/installer" rev-parse "$release_tag" >/dev/null 2>&1; then
        [ "$json_output" = true ] || printf "tag\tinstaller\t%s\talready-exists\n" "$release_tag"
    else
        [ "$json_output" = true ] || printf "tag\tinstaller\t%s\n" "$release_tag"
        if [ "$signed_tag" = true ]; then
            git -C "$repo_root/installer" tag -s "$release_tag" -m "Release $release_tag"
        else
            git -C "$repo_root/installer" tag -a "$release_tag" -m "Release $release_tag"
        fi
    fi

    if [ "$json_output" = true ]; then
        git -C "$repo_root/installer" push --quiet origin "$release_tag" >/dev/null 2>&1
    else
        git -C "$repo_root/installer" push origin "$release_tag"
    fi
}

update_candidate_ref() {
    if [ "$mode" != "--push" ]; then
        return 0
    fi
    if [ -z "$candidate_ref" ]; then
        return 0
    fi

    current_stage="candidate:installer"
    [ "$json_output" = true ] || printf "candidate\tinstaller\t%s\n" "$candidate_ref"
    if [ "$json_output" = true ]; then
        git -C "$repo_root/installer" push --quiet origin "HEAD:refs/heads/$candidate_ref" >/dev/null 2>&1
    else
        git -C "$repo_root/installer" push origin "HEAD:refs/heads/$candidate_ref"
    fi
}

publish_github_release() {
    if [ "$mode" != "--push" ] || [ "$github_release" != true ]; then
        return 0
    fi
    if [ -z "$release_tag" ]; then
        printf "--github-release requires --tag TAG\n" >&2
        return 2
    fi
    if ! command -v gh >/dev/null 2>&1; then
        printf "--github-release requires the GitHub CLI: gh\n" >&2
        return 2
    fi

    current_stage="release:github"
    local -a command=(gh release create "$release_tag" --repo dotbrains/set-me-up-installer)
    if [ -n "$release_title" ]; then
        command+=(--title "$release_title")
    else
        command+=(--title "set-me-up installer $release_tag")
    fi
    if [ -n "$release_notes" ]; then
        command+=(--notes "$release_notes")
    else
        command+=(--generate-notes)
    fi
    if [ "$json_output" = true ]; then
        "${command[@]}" >/dev/null 2>&1
    else
        "${command[@]}"
    fi
}

candidate_check() {
    local installer_target_head
    local remote_candidate_head

    current_stage="candidate:freshness"
    installer_target_head="$(repo_head installer)"
    remote_candidate_head="$(candidate_head)"
    [ "$(candidate_fresh "$installer_target_head" "$remote_candidate_head")" = true ] && \
        [ "$(candidate_age_ok "$(candidate_age_days "$remote_candidate_head")")" = true ]
}

self_test() {
    current_stage="self-test"
    SMU_RELEASE_HELPER_SELF_TEST=1 "$repo_root/scripts/tests/test-setup-update.sh"
}

if [ "$mode" = "--self-test" ]; then
    self_test
    [ "$json_output" = true ] && release_status_json 0 true false false "complete" || \
        printf "release install/update self-test complete\n"
    exit 0
fi

if [ "$mode" = "--publish-plan" ]; then
    json_output=true
    release_status_json 0 false false false "publish-plan"
    exit 0
fi

validate_repo "installer" "scripts/validate.sh --all"
validate_repo "blueprint" "scripts/validate.sh"
validate_repo "tests" "scripts/validate.sh"

require_clean_repo "installer"
require_clean_repo "blueprint"
require_clean_repo "tests"

if [ "$mode" = "--candidate-check" ]; then
    candidate_check
fi

if [ "$mode" = "--push" ]; then
    push_repo "installer" "main"
    push_repo "blueprint" "master"
    push_repo "tests" "main"
    update_candidate_ref
fi

tag_installer_release
publish_github_release

if [ "$json_output" = true ]; then
    tagged=false
    [ -n "$release_tag" ] && tagged=true
    pushed=false
    [ "$mode" = "--push" ] && pushed=true
    release_status_json 0 true "$pushed" "$tagged" "complete"
else
    printf "release install/update %s complete\n" "${mode#--}"
    [ -n "$release_tag" ] && printf "release tag\t%s\n" "$release_tag"
    [ "$signed_tag" = true ] && printf "release provenance\tsigned-tag\n"
    [ "$github_release" = true ] && printf "github release\t%s\n" "$release_tag"
    [ "$mode" = "--push" ] && [ -n "$candidate_ref" ] && printf "candidate ref\t%s\n" "$candidate_ref"
fi
