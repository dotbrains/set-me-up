#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

set -euo pipefail

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

print_ambiguities_json() {
    local count
    local comma=""
    local index
    local intent
    local score

    count="$(high_confidence_intent_count)"
    printf "["
    [ "$count" -gt 1 ] || {
        printf "]"
        return 0
    }
    IFS=',' read -r -a intents <<< "$matched_intents"
    IFS=',' read -r -a scores <<< "$matched_intent_scores"
    for index in "${!intents[@]}"; do
        intent="${intents[$index]}"
        score="${scores[$index]}"
        [ "$(confidence_for_score "$score")" = "high" ] || continue
        printf '%s{"intent":"%s","confidence":"high","score":%s}' \
            "$comma" "$(smu_json_escape "$intent")" "$score"
        comma=","
    done
    printf "]"
}

print_risk_summary_json() {
    local counts
    local high
    local medium
    local low
    local rest
    local blocking=false

    counts="$(risk_summary_counts)"
    high="${counts%%,*}"
    rest="${counts#*,}"
    medium="${rest%%,*}"
    low="${rest##*,}"
    strict_has_blocking_risks && blocking=true

    printf '{"high":%s,"medium":%s,"low":%s,"blocking":%s,"reasons":' \
        "$high" "$medium" "$low" "$blocking"
    json_array_from_csv "$(blocking_risk_reasons)"
    printf "}"
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

    printf "path\trole\tconfidence\tscore\trisk\trepo\troute\tstate\tsync\tvalidator\tdocs\twarnings\tsummary\n"
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
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$path" "$role" "$(confidence_for_score "$score")" "$score" \
            "$(risk_level_for_path "$path")" "$repo" "$route_id" "$(state_for_path "$path")" \
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
    printf ',"riskSummary":'
    print_risk_summary_json
    printf ',"ambiguities":'
    print_ambiguities_json
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
        printf '%s{"path":"%s","role":"%s","confidence":"%s","score":%s,"risk":"%s","source":"%s","explanation":"%s","repo":"%s","route":"%s","summary":"%s","keywords":"%s","state":"%s","sync":"%s","validator":"%s","docs":' \
            "$comma" "$(smu_json_escape "$path")" "$(smu_json_escape "$role")" \
            "$(confidence_for_score "$score")" "$score" "$(risk_level_for_path "$path")" \
            "$(smu_json_escape "$source")" "$(smu_json_escape "$reason")" \
            "$(smu_json_escape "$repo")" "$(smu_json_escape "$route_id")" \
            "$(smu_json_escape "$summary")" "$(smu_json_escape "$keywords")" \
            "$(smu_json_escape "$(state_for_path "$path")")" \
            "$(smu_json_escape "$(sync_for_path "$path")")" \
            "$(smu_json_escape "$(validator_label_for_path "$path")")"
        json_array_from_csv "$(docs_for_path "$path")"
        printf ',"warnings":'
        json_array_from_csv "$(doc_warnings_for_path "$path")"
        printf ',"risks":'
        json_array_from_csv "$(risk_flags_for_path "$path")"
        printf "}"
        comma=","
    done
    printf '],"nextCommands":'
    json_array_from_semicolon "$next_commands"
    printf "}\n"
}

print_plan() {
    printf "agent intake plan: %s\n" "$query"
    printf "1. Read docs for selected repositories.\n"
    printf "2. Inspect primary repositories first.\n"
    printf "3. Edit the owning repository or repositories.\n"
    printf "4. Run validation commands:\n"
    print_next_commands_tsv | while IFS=$'\t' read -r _ _ command; do
        printf "   - %s\n" "$command"
    done
    printf "5. Report changed repositories, checks, and remaining risks.\n"
    printf "\nselected repositories:\n"
    print_tsv
}
