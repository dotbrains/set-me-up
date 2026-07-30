#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC2154

set -euo pipefail
strict=0
minimum_score=40

strict_risk_csv() {
    printf "dirty,detached,diverged,behind,missing,not-git,no-validator"
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
