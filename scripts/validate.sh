#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/repos.sh"
source "$repo_root/scripts/lib/manifest-index.sh"
source "$repo_root/scripts/lib/check-runner.sh"

mode="--all"
verbose=0

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
    smu_run_timed_check "$@"
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
        scripts/configure-branch-protection.sh \
        scripts/release-install-update.sh scripts/tree-smoke-test.sh \
        scripts/validate-json-schemas.sh \
        scripts/tests/test-helpers.sh \
        scripts/tests/test-setup-update.sh scripts/tests/test-manifests.sh \
        scripts/tests/test-routes-doctor.sh scripts/tests/test-lib-modules.sh \
        scripts/tests/test-output-snapshots.sh \
        scripts/generate-command-docs.sh scripts/lib/repos.sh \
        scripts/lib/repo-state.sh scripts/lib/routes.sh \
        scripts/lib/validators.sh scripts/lib/json.sh \
        scripts/lib/agent-intake.sh scripts/lib/manifest-index.sh \
        scripts/lib/check-runner.sh scripts/lib/repo-health.sh \
        scripts/lib/agent-intake-match.sh scripts/lib/agent-intake-render.sh \
        scripts/lib/release-readiness-render.sh
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
        scripts/change-report.sh scripts/configure-branch-protection.sh \
        scripts/release-install-update.sh \
        scripts/tree-smoke-test.sh \
        scripts/validate-json-schemas.sh \
        scripts/tests/test-helpers.sh scripts/tests/test-setup-update.sh \
        scripts/tests/test-manifests.sh scripts/tests/test-routes-doctor.sh \
        scripts/tests/test-lib-modules.sh \
        scripts/tests/test-output-snapshots.sh \
        scripts/generate-command-docs.sh scripts/lib/repos.sh \
        scripts/lib/repo-state.sh scripts/lib/routes.sh \
        scripts/lib/validators.sh scripts/lib/json.sh \
        scripts/lib/agent-intake.sh scripts/lib/manifest-index.sh \
        scripts/lib/check-runner.sh scripts/lib/repo-health.sh \
        scripts/lib/agent-intake-match.sh scripts/lib/agent-intake-render.sh \
        scripts/lib/release-readiness-render.sh
}

markdown_checks() {
    npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
        "#installer" "#modules" "#shared" "#tests" "#utilities"
}

manifest_checks() {
    smu_validate_repos_manifest scripts/repos.txt
}

route_map_checks() {
    smu_validate_route_map scripts/repos.txt scripts/agent-routes.txt
}

intent_map_checks() {
    smu_validate_intent_map scripts/repos.txt scripts/agent-intents.txt
}

repo_validator_checks() {
    smu_validate_repo_validators scripts/repos.txt scripts/repo-validators.txt
}

coverage_checks() {
    local doctor_output
    local missing_validators

    smu_check_runner_init "$verbose"
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
    smu_check_runner_summary "coverage"
}

agent_checks() {
    smu_check_runner_init "$verbose"
    route_map_checks
    intent_map_checks
    run_timed_check "agent intake json" scripts/agent-intake.sh --json theme
    run_timed_check "agent intake plan" scripts/agent-intake.sh --plan theme
    run_timed_check "agent intake fixtures" scripts/agent-intake-fixtures.sh --check
    run_timed_check "agent intake schema" scripts/validate-json-schemas.sh
    grep -q "Agent Intake Contract" scripts/docs/AGENT-INTAKE.md
    smu_check_runner_summary "agent"
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
        scripts/configure-branch-protection.sh
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
        scripts/lib/manifest-index.sh
        scripts/lib/check-runner.sh
        scripts/lib/repo-health.sh
        scripts/lib/agent-intake-match.sh
        scripts/lib/agent-intake-render.sh
        scripts/lib/release-readiness-render.sh
        scripts/test-root-scripts.sh
        scripts/tests/test-helpers.sh
        scripts/tests/test-setup-update.sh
        scripts/tests/test-manifests.sh
        scripts/tests/test-routes-doctor.sh
        scripts/tests/test-lib-modules.sh
        scripts/tests/test-output-snapshots.sh
        scripts/tests/fixtures/output-snapshots/agent-intake-theme.json
        scripts/tests/fixtures/output-snapshots/health-report.json
        scripts/tests/fixtures/output-snapshots/release-readiness.json
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
        scripts/schemas/release-readiness.schema.json
        scripts/docs/SCRIPTS-DETAILS.md
        scripts/docs/COMMANDS.md
        scripts/docs/AGENT-INTAKE.md
        scripts/docs/INSTALL-UPDATE-RELEASE.md
        scripts/docs/INSTALL-UPDATE-COMPATIBILITY.md
        scripts/docs/INSTALL-UPDATE-RELEASE-NOTES.md
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
    [ -x scripts/configure-branch-protection.sh ] || {
        printf "scripts/configure-branch-protection.sh must be executable\\n" >&2
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
