#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

set -euo pipefail

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
