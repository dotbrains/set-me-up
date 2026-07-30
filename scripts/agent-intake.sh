#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
intents_file="$repo_root/scripts/agent-intents.txt"
format="--tsv"
query=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--tsv|--json] <query>\n" "$0" >&2
}

normalize() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

matches_query() {
    local haystack="$1"
    local needle="$2"

    [[ "$(normalize "$haystack")" == *"$(normalize "$needle")"* ]]
}

manifest_has_path() {
    local wanted_path="$1"
    local repo
    local path
    local category

    [ "$wanted_path" = "." ] && return 0

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        [ "$path" = "$wanted_path" ] && return 0
    done < "$repos_file"

    return 1
}

repo_name_for_path() {
    local wanted_path="$1"
    local repo
    local path
    local category

    [ "$wanted_path" = "." ] && {
        printf "set-me-up"
        return 0
    }

    while IFS='|' read -r repo path category _ || [ -n "$repo" ]; do
        [[ "$repo" =~ ^[[:space:]]*# || -z "$repo" ]] && continue
        : "$category"
        if [ "$path" = "$wanted_path" ]; then
            printf "%s" "$repo"
            return 0
        fi
    done < "$repos_file"

    return 1
}

route_details_for_path() {
    local path="$1"
    local route

    if route="$(smu_route_for_path "$routes_file" "$path")"; then
        printf "%s" "$route"
    elif [ "$path" = "." ]; then
        printf "root-orchestration|Root setup orchestration|setup,update,manifest,root,validation,ci"
    else
        printf "||"
    fi
}

validator_label_for_path() {
    local path="$1"
    local validator

    if [ "$path" = "." ]; then
        printf "scripts/validate.sh --all"
    elif validator="$(smu_validator_for_repo "$validators_file" "$path")"; then
        smu_validator_label "$validator"
    else
        printf "none"
    fi
}

state_for_path() {
    local path="$1"

    if [ "$path" = "." ]; then
        printf "root"
    else
        smu_repo_state "$path"
    fi
}

sync_for_path() {
    local path="$1"
    local state

    if [ "$path" = "." ]; then
        printf "local"
        return 0
    fi

    state="$(smu_repo_state "$path")"
    if [ "$state" = "missing" ] || [ "$state" = "not-git" ] || \
        [ "$state" = "detached" ]; then
        printf "unknown"
    else
        smu_repo_sync_status "$path"
    fi
}

docs_for_path() {
    local path="$1"
    local docs=""
    local candidate

    for candidate in AGENTS.md CLAUDE.md README.md CONTRIBUTING.md; do
        if [ "$path" = "." ]; then
            [ -f "$repo_root/$candidate" ] || continue
        else
            [ -f "$repo_root/$path/$candidate" ] || continue
        fi
        [ -z "$docs" ] || docs+=","
        docs+="$candidate"
    done

    printf "%s" "$docs"
}

append_path() {
    local path="$1"
    local role="$2"

    manifest_has_path "$path" || return 0
    case ",$selected_paths," in
        *",$path,"*) return 0 ;;
    esac
    selected_paths+="${selected_paths:+,}$path"
    selected_roles+="${selected_roles:+,}$role"
}

append_paths() {
    local paths="$1"
    local role="$2"
    local path

    [ -n "$paths" ] || return 0
    IFS=',' read -r -a path_list <<< "$paths"
    for path in "${path_list[@]}"; do
        [ -n "$path" ] || continue
        append_path "$path" "$role"
    done
}

select_from_intents() {
    local intent_id
    local primary_paths
    local related_paths
    local summary
    local keywords
    local extra
    local haystack

    [ -f "$intents_file" ] || return 1

    while IFS='|' read -r intent_id primary_paths related_paths summary keywords extra || \
        [ -n "$intent_id" ]; do
        [[ "$intent_id" =~ ^[[:space:]]*# || -z "$intent_id" ]] && continue
        : "${extra:-}"
        haystack="$intent_id $summary $keywords $primary_paths $related_paths"
        matches_query "$haystack" "$query" || continue
        matched_intents+="${matched_intents:+,}$intent_id"
        append_paths "$primary_paths" "primary"
        append_paths "$related_paths" "related"
    done < "$intents_file"

    [ -n "$matched_intents" ]
}

select_from_routes() {
    local route_id
    local path
    local summary
    local keywords
    local extra
    local haystack

    while IFS='|' read -r route_id path summary keywords extra || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "${extra:-}"
        haystack="$route_id $path $summary $keywords"
        matches_query "$haystack" "$query" || continue
        append_path "$path" "primary"
    done < "$routes_file"
}

print_tsv() {
    local index
    local path
    local role
    local repo
    local route
    local route_id
    local rest
    local summary
    local keywords

    printf "path\trole\trepo\troute\tstate\tsync\tvalidator\tdocs\tsummary\n"
    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    for index in "${!paths[@]}"; do
        path="${paths[$index]}"
        role="${roles[$index]}"
        repo="$(repo_name_for_path "$path")"
        route="$(route_details_for_path "$path")"
        route_id="${route%%|*}"
        rest="${route#*|}"
        summary="${rest%%|*}"
        keywords="${rest#*|}"
        : "$keywords"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$path" "$role" "$repo" "$route_id" "$(state_for_path "$path")" \
            "$(sync_for_path "$path")" "$(validator_label_for_path "$path")" \
            "$(docs_for_path "$path")" "$summary"
    done
    printf "next\tcommand\t%s\n" "scripts/validate-repos.sh --changed"
}

json_array_from_csv() {
    local csv="$1"
    local comma=""
    local item

    printf "["
    [ -n "$csv" ] || {
        printf "]"
        return 0
    }
    IFS=',' read -r -a items <<< "$csv"
    for item in "${items[@]}"; do
        printf '%s"%s"' "$comma" "$(smu_json_escape "$item")"
        comma=","
    done
    printf "]"
}

print_json() {
    local index
    local path
    local role
    local repo
    local route
    local route_id
    local rest
    local summary
    local keywords
    local comma=""

    printf '{"query":"%s","matchedIntents":' "$(smu_json_escape "$query")"
    json_array_from_csv "$matched_intents"
    printf ',"repositories":['
    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    for index in "${!paths[@]}"; do
        path="${paths[$index]}"
        role="${roles[$index]}"
        repo="$(repo_name_for_path "$path")"
        route="$(route_details_for_path "$path")"
        route_id="${route%%|*}"
        rest="${route#*|}"
        summary="${rest%%|*}"
        keywords="${rest#*|}"
        printf '%s{"path":"%s","role":"%s","repo":"%s","route":"%s","summary":"%s","keywords":"%s","state":"%s","sync":"%s","validator":"%s","docs":' \
            "$comma" "$(smu_json_escape "$path")" "$(smu_json_escape "$role")" \
            "$(smu_json_escape "$repo")" "$(smu_json_escape "$route_id")" \
            "$(smu_json_escape "$summary")" "$(smu_json_escape "$keywords")" \
            "$(smu_json_escape "$(state_for_path "$path")")" \
            "$(smu_json_escape "$(sync_for_path "$path")")" \
            "$(smu_json_escape "$(validator_label_for_path "$path")")"
        json_array_from_csv "$(docs_for_path "$path")"
        printf "}"
        comma=","
    done
    printf '],"nextCommands":["scripts/validate-repos.sh --changed"]}\n'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tsv | --json)
            format="$1"
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            usage
            exit 2
            ;;
        *)
            [ -z "$query" ] || {
                usage
                exit 2
            }
            query="$1"
            ;;
    esac
    shift
done

[ -n "$query" ] || {
    usage
    exit 2
}

cd "$repo_root"
smu_validate_repos_manifest "$repos_file"

selected_paths=""
selected_roles=""
matched_intents=""

select_from_intents || select_from_routes

if [ -z "$selected_paths" ]; then
    printf "No agent intake matched: %s\n" "$query" >&2
    exit 1
fi

case "$format" in
    --json)
        print_json
        ;;
    --tsv)
        print_tsv
        ;;
esac
