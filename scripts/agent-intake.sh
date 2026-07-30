#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repos_file="$repo_root/scripts/repos.txt"
routes_file="$repo_root/scripts/agent-routes.txt"
validators_file="$repo_root/scripts/repo-validators.txt"
intents_file="$repo_root/scripts/agent-intents.txt"
format="--tsv"
explain=0
query=""

source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/routes.sh"
source "$repo_root/scripts/lib/repo-state.sh"
source "$repo_root/scripts/lib/validators.sh"
source "$repo_root/scripts/lib/json.sh"

usage() {
    printf "Usage: %s [--tsv|--json] [--explain] <query>\n" "$0" >&2
}

normalize() {
    printf "%s" "$1" | tr '[:upper:]' '[:lower:]'
}

matches_query() {
    local haystack="$1"
    local needle="$2"
    local haystack_normal
    local needle_normal
    local word

    haystack_normal="$(normalize "$haystack")"
    needle_normal="$(normalize "$needle")"

    [[ "$haystack_normal" == *"$needle_normal"* ]] && return 0

    for word in $needle_normal; do
        [[ "$haystack_normal" == *"$word"* ]] || return 1
    done
}

score_match() {
    local id="$1"
    local summary="$2"
    local keywords="$3"
    local paths="$4"
    local query_normal
    local keyword
    local score=0

    query_normal="$(normalize "$query")"
    [ "$(normalize "$id")" = "$query_normal" ] && score=$((score + 100))
    matches_query "$id" "$query" && score=$((score + 60))
    matches_query "$keywords" "$query" && score=$((score + 40))
    matches_query "$summary" "$query" && score=$((score + 20))
    matches_query "$paths" "$query" && score=$((score + 10))

    IFS=',' read -r -a keyword_list <<< "$keywords"
    for keyword in "${keyword_list[@]}"; do
        [ "$(normalize "$keyword")" = "$query_normal" ] && score=$((score + 80))
    done

    printf "%s" "$score"
}

confidence_for_score() {
    local score="$1"

    if [ "$score" -ge 100 ]; then
        printf "high"
    elif [ "$score" -ge 40 ]; then
        printf "medium"
    else
        printf "low"
    fi
}

append_csv_unique() {
    local current="$1"
    local item="$2"

    case ",$current," in
        *",$item,"*)
            printf "%s" "$current"
            ;;
        *)
            printf "%s%s%s" "$current" "${current:+,}" "$item"
            ;;
    esac
}

append_semicolon_unique() {
    local current="$1"
    local item="$2"

    case ";$current;" in
        *";$item;"*)
            printf "%s" "$current"
            ;;
        *)
            printf "%s%s%s" "$current" "${current:+;}" "$item"
            ;;
    esac
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

doc_warnings_for_path() {
    local path="$1"
    local base="$repo_root/$path"
    local warnings=""

    [ "$path" = "." ] && base="$repo_root"
    [ -f "$base/AGENTS.md" ] || \
        warnings="$(append_csv_unique "$warnings" "missing AGENTS.md")"
    [ -f "$base/README.md" ] || [ -f "$base/README" ] || \
        warnings="$(append_csv_unique "$warnings" "missing README")"

    printf "%s" "$warnings"
}

append_path() {
    local path="$1"
    local role="$2"
    local source="$3"
    local score="$4"
    local reason="$5"

    manifest_has_path "$path" || return 0
    case ",$selected_paths," in
        *",$path,"*) return 0 ;;
    esac
    selected_paths+="${selected_paths:+,}$path"
    selected_roles+="${selected_roles:+,}$role"
    selected_sources+="${selected_sources:+,}$source"
    selected_scores+="${selected_scores:+,}$score"
    selected_reasons+="${selected_reasons:+|}$reason"
}

append_paths() {
    local paths="$1"
    local role="$2"
    local source="$3"
    local score="$4"
    local reason="$5"
    local path

    [ -n "$paths" ] || return 0
    IFS=',' read -r -a path_list <<< "$paths"
    for path in "${path_list[@]}"; do
        [ -n "$path" ] || continue
        append_path "$path" "$role" "$source" "$score" "$reason"
    done
}

select_from_intents() {
    local intent_id
    local primary_paths
    local related_paths
    local validation_commands
    local summary
    local keywords
    local extra
    local haystack
    local score
    local confidence
    local reason
    local matched=0

    [ -f "$intents_file" ] || return 1

    while IFS='|' read -r intent_id primary_paths related_paths validation_commands summary keywords extra || \
        [ -n "$intent_id" ]; do
        [[ "$intent_id" =~ ^[[:space:]]*# || -z "$intent_id" ]] && continue
        : "${extra:-}"
        haystack="$intent_id $summary $keywords $primary_paths $related_paths"
        matches_query "$haystack" "$query" || continue
        score="$(score_match "$intent_id" "$summary" "$keywords" "$primary_paths,$related_paths")"
        confidence="$(confidence_for_score "$score")"
        reason="intent:$intent_id confidence:$confidence score:$score"
        matched_intents+="${matched_intents:+,}$intent_id"
        matched_intent_scores+="${matched_intent_scores:+,}$score"
        append_paths "$primary_paths" "primary" "$intent_id" "$score" "$reason"
        append_paths "$related_paths" "related" "$intent_id" "$score" "$reason"
        append_validation_commands "$validation_commands"
        matched=1
    done < "$intents_file"

    [ "$matched" -eq 1 ]
}

select_from_routes() {
    local route_id
    local path
    local summary
    local keywords
    local extra
    local haystack
    local score
    local reason

    while IFS='|' read -r route_id path summary keywords extra || [ -n "$route_id" ]; do
        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue
        : "${extra:-}"
        haystack="$route_id $path $summary $keywords"
        matches_query "$haystack" "$query" || continue
        score="$(score_match "$route_id" "$summary" "$keywords" "$path")"
        reason="route:$route_id confidence:$(confidence_for_score "$score") score:$score"
        append_path "$path" "primary" "$route_id" "$score" "$reason"
    done < "$routes_file"
}

append_validation_commands() {
    local commands="$1"
    local command

    [ -n "$commands" ] || return 0
    IFS=';' read -r -a command_list <<< "$commands"
    for command in "${command_list[@]}"; do
        [ -n "$command" ] || continue
        next_commands="$(append_semicolon_unique "$next_commands" "$command")"
    done
}

rank_selected_paths() {
    local i
    local j
    local tmp

    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    IFS=',' read -r -a sources <<< "$selected_sources"
    IFS=',' read -r -a scores <<< "$selected_scores"
    IFS='|' read -r -a reasons <<< "$selected_reasons"

    for i in "${!paths[@]}"; do
        j=$((i + 1))
        while [ "$j" -lt "${#paths[@]}" ]; do
            if [ "${scores[$j]}" -gt "${scores[$i]}" ]; then
                tmp="${paths[$i]}"; paths[$i]="${paths[$j]}"; paths[$j]="$tmp"
                tmp="${roles[$i]}"; roles[$i]="${roles[$j]}"; roles[$j]="$tmp"
                tmp="${sources[$i]}"; sources[$i]="${sources[$j]}"; sources[$j]="$tmp"
                tmp="${scores[$i]}"; scores[$i]="${scores[$j]}"; scores[$j]="$tmp"
                tmp="${reasons[$i]}"; reasons[$i]="${reasons[$j]}"; reasons[$j]="$tmp"
            fi
            j=$((j + 1))
        done
    done

    selected_paths=""
    selected_roles=""
    selected_sources=""
    selected_scores=""
    selected_reasons=""
    for i in "${!paths[@]}"; do
        selected_paths+="${selected_paths:+,}${paths[$i]}"
        selected_roles+="${selected_roles:+,}${roles[$i]}"
        selected_sources+="${selected_sources:+,}${sources[$i]}"
        selected_scores+="${selected_scores:+,}${scores[$i]}"
        selected_reasons+="${selected_reasons:+|}${reasons[$i]}"
    done
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
    local source
    local score
    local reason

    printf "path\trole\tconfidence\tscore\trepo\troute\tstate\tsync\tvalidator\tdocs\twarnings\tsummary\n"
    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    IFS=',' read -r -a sources <<< "$selected_sources"
    IFS=',' read -r -a scores <<< "$selected_scores"
    IFS='|' read -r -a reasons <<< "$selected_reasons"
    for index in "${!paths[@]}"; do
        path="${paths[$index]}"
        role="${roles[$index]}"
        source="${sources[$index]}"
        score="${scores[$index]}"
        reason="${reasons[$index]}"
        repo="$(repo_name_for_path "$path")"
        route="$(route_details_for_path "$path")"
        route_id="${route%%|*}"
        rest="${route#*|}"
        summary="${rest%%|*}"
        keywords="${rest#*|}"
        : "$keywords"
        : "$source" "$reason"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$path" "$role" "$(confidence_for_score "$score")" "$score" \
            "$repo" "$route_id" "$(state_for_path "$path")" \
            "$(sync_for_path "$path")" "$(validator_label_for_path "$path")" \
            "$(docs_for_path "$path")" "$(doc_warnings_for_path "$path")" \
            "$summary"
    done
    print_next_commands_tsv
    if [ "$explain" -eq 1 ]; then
        for index in "${!paths[@]}"; do
            printf "explain\t%s\t%s\n" "${paths[$index]}" "${reasons[$index]}"
        done
    fi
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

json_array_from_semicolon() {
    local values="$1"
    local comma=""
    local item

    printf "["
    [ -n "$values" ] || {
        printf "]"
        return 0
    }
    IFS=';' read -r -a items <<< "$values"
    for item in "${items[@]}"; do
        printf '%s"%s"' "$comma" "$(smu_json_escape "$item")"
        comma=","
    done
    printf "]"
}

print_next_commands_tsv() {
    local command

    IFS=';' read -r -a command_list <<< "$next_commands"
    for command in "${command_list[@]}"; do
        [ -n "$command" ] || continue
        printf "next\tcommand\t%s\n" "$command"
    done
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
    local source
    local score
    local reason
    local comma=""

    printf '{"query":"%s","matchedIntents":' "$(smu_json_escape "$query")"
    json_array_from_csv "$matched_intents"
    printf ',"repositories":['
    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    IFS=',' read -r -a sources <<< "$selected_sources"
    IFS=',' read -r -a scores <<< "$selected_scores"
    IFS='|' read -r -a reasons <<< "$selected_reasons"
    for index in "${!paths[@]}"; do
        path="${paths[$index]}"
        role="${roles[$index]}"
        source="${sources[$index]}"
        score="${scores[$index]}"
        reason="${reasons[$index]}"
        repo="$(repo_name_for_path "$path")"
        route="$(route_details_for_path "$path")"
        route_id="${route%%|*}"
        rest="${route#*|}"
        summary="${rest%%|*}"
        keywords="${rest#*|}"
        printf '%s{"path":"%s","role":"%s","confidence":"%s","score":%s,"source":"%s","explanation":"%s","repo":"%s","route":"%s","summary":"%s","keywords":"%s","state":"%s","sync":"%s","validator":"%s","docs":' \
            "$comma" "$(smu_json_escape "$path")" "$(smu_json_escape "$role")" \
            "$(confidence_for_score "$score")" "$score" \
            "$(smu_json_escape "$source")" "$(smu_json_escape "$reason")" \
            "$(smu_json_escape "$repo")" "$(smu_json_escape "$route_id")" \
            "$(smu_json_escape "$summary")" "$(smu_json_escape "$keywords")" \
            "$(smu_json_escape "$(state_for_path "$path")")" \
            "$(smu_json_escape "$(sync_for_path "$path")")" \
            "$(smu_json_escape "$(validator_label_for_path "$path")")"
        json_array_from_csv "$(docs_for_path "$path")"
        printf ',"warnings":'
        json_array_from_csv "$(doc_warnings_for_path "$path")"
        printf "}"
        comma=","
    done
    printf '],"nextCommands":'
    json_array_from_semicolon "$next_commands"
    printf "}\n"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --tsv | --json)
            format="$1"
            ;;
        --explain)
            explain=1
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
selected_sources=""
selected_scores=""
selected_reasons=""
matched_intents=""
matched_intent_scores=""
next_commands="scripts/validate-repos.sh --changed"

select_from_intents || select_from_routes

if [ -z "$selected_paths" ]; then
    printf "No agent intake matched: %s\n" "$query" >&2
    exit 1
fi

rank_selected_paths

case "$format" in
    --json)
        print_json
        ;;
    --tsv)
        print_tsv
        ;;
esac
