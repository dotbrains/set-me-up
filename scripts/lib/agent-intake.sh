#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2154

set -euo pipefail
strict=0
minimum_score=40

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

strict_risk_csv() {
    printf "dirty,detached,diverged,behind,missing,not-git,no-validator"
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
    smu_manifest_has_path "$repos_file" "$1"
}

repo_name_for_path() {
    smu_repo_name_for_path "$repos_file" "$1" "set-me-up"
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
    smu_repo_health_sync_for_state "$path" "$state"
}

docs_for_path() {
    local path="$1"
    smu_repo_health_docs "$repo_root" "$path"
}

doc_warnings_for_path() {
    local path="$1"
    smu_repo_health_doc_warnings "$repo_root" "$path"
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

filter_selected_paths() {
    local i
    local keep_paths=""
    local keep_roles=""
    local keep_sources=""
    local keep_scores=""
    local keep_reasons=""
    local best_score=0

    IFS=',' read -r -a paths <<< "$selected_paths"
    IFS=',' read -r -a roles <<< "$selected_roles"
    IFS=',' read -r -a sources <<< "$selected_sources"
    IFS=',' read -r -a scores <<< "$selected_scores"
    IFS='|' read -r -a reasons <<< "$selected_reasons"

    for i in "${!scores[@]}"; do
        [ "${scores[$i]}" -gt "$best_score" ] && best_score="${scores[$i]}"
    done

    for i in "${!paths[@]}"; do
        if [ "${scores[$i]}" -ge "$minimum_score" ] || [ "${scores[$i]}" -eq "$best_score" ]; then
            keep_paths+="${keep_paths:+,}${paths[$i]}"
            keep_roles+="${keep_roles:+,}${roles[$i]}"
            keep_sources+="${keep_sources:+,}${sources[$i]}"
            keep_scores+="${keep_scores:+,}${scores[$i]}"
            keep_reasons+="${keep_reasons:+|}${reasons[$i]}"
        fi
    done

    selected_paths="$keep_paths"
    selected_roles="$keep_roles"
    selected_sources="$keep_sources"
    selected_scores="$keep_scores"
    selected_reasons="$keep_reasons"
}

risk_flags_for_path() {
    local path="$1"
    local state
    local sync
    local validator
    local risks=""

    state="$(state_for_path "$path")"
    sync="$(sync_for_path "$path")"
    validator="$(validator_label_for_path "$path")"

    case "$state" in
        dirty|detached|missing|not-git)
            risks="$(append_csv_unique "$risks" "$state")"
            ;;
    esac
    case "$sync" in
        behind:*)
            risks="$(append_csv_unique "$risks" "behind")"
            ;;
        diverged:*)
            risks="$(append_csv_unique "$risks" "diverged")"
            ;;
    esac
    [ "$validator" = "none" ] && risks="$(append_csv_unique "$risks" "no-validator")"
    if [ -n "$(doc_warnings_for_path "$path")" ]; then
        risks="$(append_csv_unique "$risks" "missing-docs")"
    fi

    printf "%s" "$risks"
}

risk_level_for_path() {
    local risks

    risks="$(risk_flags_for_path "$1")"
    case ",$risks," in
        *,dirty,*|*,detached,*|*,diverged,*|*,missing,*|*,not-git,*|*,no-validator,*)
            printf "high"
            ;;
        *,behind,*|*,missing-docs,*)
            printf "medium"
            ;;
        *)
            printf "low"
            ;;
    esac
}

strict_has_blocking_risks() {
    local path
    local risks

    IFS=',' read -r -a paths <<< "$selected_paths"
    for path in "${paths[@]}"; do
        risks="$(risk_flags_for_path "$path")"
        case ",$risks," in
            *,dirty,*|*,detached,*|*,diverged,*|*,behind,*|*,missing,*|*,not-git,*|*,no-validator,*)
                return 0
                ;;
        esac
    done
    return 1
}

risk_summary_counts() {
    local path
    local level
    local high=0
    local medium=0
    local low=0

    IFS=',' read -r -a paths <<< "$selected_paths"
    for path in "${paths[@]}"; do
        level="$(risk_level_for_path "$path")"
        case "$level" in
            high)
                high=$((high + 1))
                ;;
            medium)
                medium=$((medium + 1))
                ;;
            low)
                low=$((low + 1))
                ;;
        esac
    done

    printf "%s,%s,%s" "$high" "$medium" "$low"
}

blocking_risk_reasons() {
    local path
    local risks
    local blocking_reasons=""
    local risk
    local -a paths=()
    local -a risk_list=()

    [ -n "$selected_paths" ] || {
        printf "%s" "$blocking_reasons"
        return 0
    }
    IFS=',' read -r -a paths <<< "$selected_paths"
    for path in "${paths[@]}"; do
        risks="$(risk_flags_for_path "$path")"
        [ -n "$risks" ] || continue
        risk_list=()
        IFS=',' read -r -a risk_list <<< "$risks"
        for risk in "${risk_list[@]}"; do
            [ -n "$risk" ] || continue
            case "$risk" in
                dirty|detached|diverged|behind|missing|not-git|no-validator)
                    blocking_reasons="$(append_csv_unique "$blocking_reasons" "$path:$risk")"
                    ;;
            esac
        done
    done

    printf "%s" "$blocking_reasons"
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

high_confidence_intent_count() {
    local score
    local count=0

    [ -n "$matched_intent_scores" ] || {
        printf "0"
        return 0
    }
    IFS=',' read -r -a scores <<< "$matched_intent_scores"
    for score in "${scores[@]}"; do
        [ "$(confidence_for_score "$score")" = "high" ] && count=$((count + 1))
    done
    printf "%s" "$count"
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

run_agent_intake() {
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
        return 1
    fi

    filter_selected_paths
    rank_selected_paths

    case "$format" in
        --json)
            print_json
            ;;
        --plan)
            print_plan
            ;;
        --tsv)
            print_tsv
            ;;
    esac

    if [ "$strict" -eq 1 ] && strict_has_blocking_risks; then
        printf "Strict agent intake failed: blocking risks present.\n" >&2
        return 1
    fi
}
