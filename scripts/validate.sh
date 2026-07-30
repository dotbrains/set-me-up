#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/repos.sh"

mode="--all"
verbose=0
timed_checks_passed=0

usage() {
    printf "Usage: %s [--all|--bash|--shell|--markdown|--structure|--coverage|--agent|--test] [--verbose]\\n" "$0" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all|--bash|--shell|--markdown|--structure|--coverage|--agent|--test)
            mode="$1"
            ;;
        --verbose)
            verbose=1
            ;;
        -h|--help)
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

run_timed_check() {
    local label="$1"
    local timeout_seconds="${SMU_VALIDATE_TIMEOUT:-45}"
    shift

    printf "checking %s\n" "$label"
    python3 - "$label" "$timeout_seconds" "$verbose" "$@" <<'PY'
import subprocess
import sys

label = sys.argv[1]
timeout_seconds = int(sys.argv[2])
verbose = sys.argv[3] == "1"
command = sys.argv[4:]
try:
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=None if verbose else subprocess.PIPE,
        stderr=None if verbose else subprocess.STDOUT,
        timeout=timeout_seconds,
    )
except subprocess.TimeoutExpired as exc:
    output = exc.output or ""
    message = f"{label}: timed out after {timeout_seconds}s"
    if output and not verbose:
        message = f"{message}\n{output}"
    raise SystemExit(message)
except subprocess.CalledProcessError as exc:
    output = exc.output or ""
    message = f"{label}: failed with exit {exc.returncode}"
    if output and not verbose:
        message = f"{message}\n{output}"
    raise SystemExit(message)
if verbose:
    pass
PY
    timed_checks_passed=$((timed_checks_passed + 1))
}

bash_checks() {
    bash -n scripts/setup.sh scripts/update.sh scripts/validate.sh \
        scripts/test-root-scripts.sh scripts/validate-repos.sh scripts/route.sh \
        scripts/agent-intake.sh scripts/agent-intake-fixtures.sh \
        scripts/doctor.sh scripts/sync-report.sh scripts/check-repo-contract.sh \
        scripts/validator-exceptions.sh scripts/capabilities.sh \
        scripts/ci-workflow-report.sh scripts/generate-docs.sh \
        scripts/native-workflow-template.sh scripts/health-report.sh \
        scripts/route-quality.sh scripts/freshness-report.sh \
        scripts/new-repo-check.sh scripts/add-repo.sh scripts/change-report.sh \
        scripts/release-install-update.sh scripts/tree-smoke-test.sh \
        scripts/validate-json-schemas.sh \
        scripts/tests/test-helpers.sh \
        scripts/tests/test-setup-update.sh scripts/tests/test-manifests.sh \
        scripts/tests/test-routes-doctor.sh \
        scripts/generate-command-docs.sh scripts/lib/repos.sh \
        scripts/lib/repo-state.sh scripts/lib/routes.sh \
        scripts/lib/validators.sh scripts/lib/json.sh \
        scripts/lib/agent-intake.sh
}

shell_checks() {
    bash_checks
    shellcheck --severity=warning scripts/setup.sh scripts/update.sh \
        scripts/validate.sh scripts/test-root-scripts.sh scripts/validate-repos.sh \
        scripts/route.sh scripts/agent-intake.sh scripts/agent-intake-fixtures.sh \
        scripts/doctor.sh scripts/sync-report.sh \
        scripts/check-repo-contract.sh scripts/validator-exceptions.sh \
        scripts/capabilities.sh scripts/ci-workflow-report.sh \
        scripts/generate-docs.sh scripts/native-workflow-template.sh \
        scripts/health-report.sh scripts/route-quality.sh \
        scripts/freshness-report.sh scripts/new-repo-check.sh scripts/add-repo.sh \
        scripts/change-report.sh scripts/release-install-update.sh \
        scripts/tree-smoke-test.sh \
        scripts/validate-json-schemas.sh \
        scripts/tests/test-helpers.sh scripts/tests/test-setup-update.sh \
        scripts/tests/test-manifests.sh scripts/tests/test-routes-doctor.sh \
        scripts/generate-command-docs.sh scripts/lib/repos.sh \
        scripts/lib/repo-state.sh scripts/lib/routes.sh \
        scripts/lib/validators.sh scripts/lib/json.sh \
        scripts/lib/agent-intake.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

manifest_checks() {
    smu_validate_repos_manifest scripts/repos.txt
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
    done < scripts/repos.txt

    return 1
}

route_map_checks() {
    local line_number=0
    local route_id
    local path
    local summary
    local keywords
    local extra
    local seen_routes=" "

    while IFS='|' read -r route_id path summary keywords extra || \
        [ -n "$route_id" ]; do
        line_number=$((line_number + 1))

        [[ "$route_id" =~ ^[[:space:]]*# || -z "$route_id" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$path" ] || [ -z "$summary" ] || \
            [ -z "$keywords" ]; then
            printf "Invalid route line %s: expected route_id|local_path|summary|keywords\\n" \
                "$line_number" >&2
            exit 1
        fi

        if [[ ! "$route_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            printf "Invalid route id on line %s: %s\\n" \
                "$line_number" "$route_id" >&2
            exit 1
        fi

        if [[ "$seen_routes" == *" $route_id "* ]]; then
            printf "Duplicate route id on line %s: %s\\n" \
                "$line_number" "$route_id" >&2
            exit 1
        fi

        if ! manifest_has_path "$path"; then
            printf "Route path on line %s is not in scripts/repos.txt: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        seen_routes+="$route_id "
    done < scripts/agent-routes.txt
}

intent_map_checks() {
    local line_number=0
    local intent_id
    local primary_paths
    local related_paths
    local validation_commands
    local summary
    local keywords
    local extra
    local seen_intents=" "
    local path
    local keyword

    while IFS='|' read -r intent_id primary_paths related_paths validation_commands summary keywords extra || \
        [ -n "$intent_id" ]; do
        line_number=$((line_number + 1))

        [[ "$intent_id" =~ ^[[:space:]]*# || -z "$intent_id" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$primary_paths" ] || \
            [ -z "$related_paths" ] || [ -z "$validation_commands" ] || \
            [ -z "$summary" ] || [ -z "$keywords" ]; then
            printf "Invalid intent line %s: expected intent_id|primary_paths|related_paths|validation_commands|summary|keywords\\n" \
                "$line_number" >&2
            exit 1
        fi

        if [[ ! "$intent_id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
            printf "Invalid intent id on line %s: %s\\n" \
                "$line_number" "$intent_id" >&2
            exit 1
        fi

        if [[ "$seen_intents" == *" $intent_id "* ]]; then
            printf "Duplicate intent id on line %s: %s\\n" \
                "$line_number" "$intent_id" >&2
            exit 1
        fi

        IFS=',' read -r -a paths <<< "$primary_paths,$related_paths"
        for path in "${paths[@]}"; do
            [ -n "$path" ] || continue
            if ! manifest_has_path "$path"; then
                printf "Intent path on line %s is not in scripts/repos.txt: %s\\n" \
                    "$line_number" "$path" >&2
                exit 1
            fi
        done

        seen_intents+="$intent_id "
    done < scripts/agent-intents.txt

    for intent_id in add-theme add-prompt change-smu-command add-managed-repo \
        add-module agent-config; do
        grep -Eq "^${intent_id}\\|" scripts/agent-intents.txt || {
            printf "Missing core agent intent: %s\\n" "$intent_id" >&2
            exit 1
        }
    done

    for keyword in theme prompt smu agent module repo; do
        grep -Eq "^[^#].*\\|[^|]*\\b${keyword}\\b[^|]*$" scripts/agent-intents.txt || {
            printf "Missing route-to-intent coverage keyword: %s\\n" "$keyword" >&2
            exit 1
        }
    done
}

repo_validator_checks() {
    local line_number=0
    local path
    local command
    local extra
    local seen_paths=" "

    while IFS='|' read -r path command extra || [ -n "$path" ]; do
        line_number=$((line_number + 1))

        [[ "$path" =~ ^[[:space:]]*# || -z "$path" ]] && continue

        if [ -n "${extra:-}" ] || [ -z "$command" ]; then
            printf "Invalid validator line %s: expected local_path|command\\n" \
                "$line_number" >&2
            exit 1
        fi

        if [[ "$seen_paths" == *" $path "* ]]; then
            printf "Duplicate validator path on line %s: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        if ! manifest_has_path "$path"; then
            printf "Validator path on line %s is not in scripts/repos.txt: %s\\n" \
                "$line_number" "$path" >&2
            exit 1
        fi

        seen_paths+="$path "
    done < scripts/repo-validators.txt
}

coverage_checks() {
    local doctor_output
    local missing_validators

    doctor_output="$(scripts/doctor.sh --summary)"
    printf "%s\\n" "$doctor_output"

    case "$doctor_output" in
        *"validators: present="*" missing=0"*)
            ;;
        *)
            printf "Validator coverage is incomplete.\\n" >&2
            return 1
            ;;
    esac

    case "$doctor_output" in
        *"routes: present="*" missing=0 drift=0"*)
            ;;
        *)
            printf "Route coverage is incomplete or drifting.\\n" >&2
            return 1
            ;;
    esac

    missing_validators="$(scripts/validate-repos.sh --missing)"
    printf "%s\\n" "$missing_validators"
    case "$missing_validators" in
        *"Missing validators for 0 repo(s)."*)
            ;;
        *)
            printf "Missing repository validators remain.\\n" >&2
            return 1
            ;;
    esac

    run_timed_check "validator exceptions" scripts/validator-exceptions.sh --checked-out --strict
    run_timed_check "repo contracts" scripts/check-repo-contract.sh --all --checked-out
    run_timed_check "workflow coverage" scripts/ci-workflow-report.sh --checked-out --strict
    run_timed_check "native workflow template" scripts/native-workflow-template.sh --check
    run_timed_check "route quality" scripts/route-quality.sh
    run_timed_check "health report json" scripts/health-report.sh --json
    run_timed_check "doctor json" scripts/doctor.sh --json
    run_timed_check "freshness report json" scripts/freshness-report.sh --json
    run_timed_check "change report json" scripts/change-report.sh --json
    run_timed_check "capabilities json" scripts/capabilities.sh --json
    run_timed_check "agent intake json" scripts/agent-intake.sh --json theme
    run_timed_check "agent intake fixtures" scripts/agent-intake-fixtures.sh --check
    run_timed_check "sync report json" scripts/sync-report.sh --json
    run_timed_check "update plan json" scripts/update.sh --plan --json
    run_timed_check "ci workflow json" scripts/ci-workflow-report.sh --checked-out --json
    run_timed_check "native workflow json" scripts/native-workflow-template.sh --check --json
    run_timed_check "json schema validation" scripts/validate-json-schemas.sh
    run_timed_check "tree smoke test" scripts/tree-smoke-test.sh
    printf "coverage checks: %s passed, 0 failed\n" "$timed_checks_passed"
}

agent_checks() {
    route_map_checks
    intent_map_checks
    run_timed_check "agent intake json" scripts/agent-intake.sh --json theme
    run_timed_check "agent intake plan" scripts/agent-intake.sh --plan theme
    run_timed_check "agent intake fixtures" scripts/agent-intake-fixtures.sh --check
    run_timed_check "agent intake schema" scripts/validate-json-schemas.sh
    grep -q "Agent Intake Contract" scripts/docs/AGENT-INTAKE.md
    printf "agent checks: %s passed, 0 failed\n" "$timed_checks_passed"
}

structure_checks() {
    local required_files=(
        README.md
        REPOSITORIES.md
        scripts/SCRIPTS.md
        scripts/setup.sh
        scripts/update.sh
        scripts/route.sh
        scripts/agent-intake.sh
        scripts/agent-intake-fixtures.sh
        scripts/doctor.sh
        scripts/sync-report.sh
        scripts/check-repo-contract.sh
        scripts/validator-exceptions.sh
        scripts/capabilities.sh
        scripts/ci-workflow-report.sh
        scripts/generate-docs.sh
        scripts/native-workflow-template.sh
        scripts/health-report.sh
        scripts/route-quality.sh
        scripts/freshness-report.sh
        scripts/new-repo-check.sh
        scripts/add-repo.sh
        scripts/change-report.sh
        scripts/release-install-update.sh
        scripts/tree-smoke-test.sh
        scripts/generate-command-docs.sh
        scripts/validate-json-schemas.sh
        scripts/repos.txt
        scripts/agent-routes.txt
        scripts/agent-intents.txt
        scripts/repo-validators.txt
        scripts/lib/repos.sh
        scripts/lib/repo-state.sh
        scripts/lib/routes.sh
        scripts/lib/validators.sh
        scripts/lib/agent-intake.sh
        scripts/test-root-scripts.sh
        scripts/tests/test-helpers.sh
        scripts/tests/test-setup-update.sh
        scripts/tests/test-manifests.sh
        scripts/tests/test-routes-doctor.sh
        scripts/validate-repos.sh
        scripts/schemas/health-report.schema.json
        scripts/schemas/health-report.example.json
        scripts/schemas/doctor.schema.json
        scripts/schemas/freshness-report.schema.json
        scripts/schemas/change-report.schema.json
        scripts/schemas/ci-workflow-report.schema.json
        scripts/schemas/native-workflow-template.schema.json
        scripts/schemas/capabilities.schema.json
        scripts/schemas/agent-intake.schema.json
        scripts/schemas/sync-report.schema.json
        scripts/schemas/update-report.schema.json
        scripts/docs/SCRIPTS-DETAILS.md
        scripts/docs/COMMANDS.md
        scripts/docs/AGENT-INTAKE.md
        scripts/docs/INSTALL-UPDATE-RELEASE.md
        scripts/docs/INSTALL-UPDATE-COMPATIBILITY.md
        .github/workflows/release-readiness.yml
        .gitignore
    )
    local required_ignores=(
        blueprint/
        docs/
        home/
        installer/
        modules/
        shared/
        tests/
        utilities/
    )

    for file in "${required_files[@]}"; do
        [ -f "$file" ] || {
            printf "Missing required file: %s\\n" "$file" >&2
            exit 1
        }
    done

    [ -x scripts/setup.sh ] || {
        printf "scripts/setup.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/update.sh ] || {
        printf "scripts/update.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/route.sh ] || {
        printf "scripts/route.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/agent-intake.sh ] || {
        printf "scripts/agent-intake.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/agent-intake-fixtures.sh ] || {
        printf "scripts/agent-intake-fixtures.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/doctor.sh ] || {
        printf "scripts/doctor.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/sync-report.sh ] || {
        printf "scripts/sync-report.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/check-repo-contract.sh ] || {
        printf "scripts/check-repo-contract.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/validator-exceptions.sh ] || {
        printf "scripts/validator-exceptions.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/capabilities.sh ] || {
        printf "scripts/capabilities.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/ci-workflow-report.sh ] || {
        printf "scripts/ci-workflow-report.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/generate-docs.sh ] || {
        printf "scripts/generate-docs.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/native-workflow-template.sh ] || {
        printf "scripts/native-workflow-template.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/health-report.sh ] || {
        printf "scripts/health-report.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/route-quality.sh ] || {
        printf "scripts/route-quality.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/freshness-report.sh ] || {
        printf "scripts/freshness-report.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/new-repo-check.sh ] || {
        printf "scripts/new-repo-check.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/add-repo.sh ] || {
        printf "scripts/add-repo.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/change-report.sh ] || {
        printf "scripts/change-report.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/release-install-update.sh ] || {
        printf "scripts/release-install-update.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/tree-smoke-test.sh ] || {
        printf "scripts/tree-smoke-test.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/generate-command-docs.sh ] || {
        printf "scripts/generate-command-docs.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/validate-json-schemas.sh ] || {
        printf "scripts/validate-json-schemas.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/test-root-scripts.sh ] || {
        printf "scripts/test-root-scripts.sh must be executable\\n" >&2
        exit 1
    }
    [ -x scripts/validate-repos.sh ] || {
        printf "scripts/validate-repos.sh must be executable\\n" >&2
        exit 1
    }

    for entry in "${required_ignores[@]}"; do
        grep -Fxq "$entry" .gitignore || {
            printf "Missing .gitignore entry: %s\\n" "$entry" >&2
            exit 1
        }
    done

    manifest_checks
    route_map_checks
    intent_map_checks
    repo_validator_checks

    grep -q "Quick Setup" README.md
    grep -q "Directory Structure" README.md
    grep -q "Repositories" README.md

    scripts/generate-docs.sh --check
    scripts/generate-command-docs.sh --check
}

test_checks() {
    scripts/test-root-scripts.sh
}

case "$mode" in
    --bash)
        bash_checks
        ;;
    --shell)
        shell_checks
        ;;
    --markdown)
        markdown_checks
        ;;
    --structure)
        structure_checks
        ;;
    --coverage)
        coverage_checks
        ;;
    --agent)
        agent_checks
        ;;
    --test)
        test_checks
        ;;
    --all)
        shell_checks
        markdown_checks
        structure_checks
        coverage_checks
        test_checks
        ;;
    *)
        usage
        exit 2
        ;;
esac
