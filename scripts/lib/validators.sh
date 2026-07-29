#!/usr/bin/env bash

set -euo pipefail

smu_declared_validator_for_repo() {
    local validators_file="$1"
    local wanted_path="$2"
    local path
    local command
    local extra

    [ -f "$validators_file" ] || return 1

    while IFS='|' read -r path command extra || [ -n "$path" ]; do
        [[ "$path" =~ ^[[:space:]]*# || -z "$path" ]] && continue
        [ "$path" = "$wanted_path" ] || continue
        [ -z "${extra:-}" ] || return 1
        [ -n "$command" ] || return 1
        printf "declared:%s" "$command"
        return 0
    done < "$validators_file"

    return 1
}

smu_validator_for_repo() {
    local validators_file="$1"
    local path="$2"
    local declared

    if declared="$(smu_declared_validator_for_repo "$validators_file" "$path")"
    then
        printf "%s" "$declared"
        return 0
    fi

    if [ -x "$path/scripts/validate.sh" ]; then
        printf "root-validator"
    elif [ -f "$path/package.json" ]; then
        printf "npm-test"
    elif [ -x "$path/test.sh" ]; then
        printf "test-script"
    else
        return 1
    fi
}

smu_validator_label() {
    case "$1" in
        root-validator)
            printf "scripts/validate.sh --all"
            ;;
        npm-test)
            printf "npm test"
            ;;
        test-script)
            printf "./test.sh"
            ;;
        declared:*)
            printf "%s" "${1#declared:}"
            ;;
        *)
            printf "%s" "$1"
            ;;
    esac
}

smu_run_validator() {
    local repo_root="$1"
    local path="$2"
    local validator="$3"

    (
        cd "$repo_root/$path"
        case "$validator" in
            root-validator)
                scripts/validate.sh --all
                ;;
            npm-test)
                npm test
                ;;
            test-script)
                ./test.sh
                ;;
            declared:*)
                bash -c "${validator#declared:}"
                ;;
            *)
                printf "Unknown validator: %s\\n" "$validator" >&2
                exit 2
                ;;
        esac
    )
}
