#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixtures_dir="$repo_root/scripts/tests/fixtures/output-snapshots"
tmp_root="${SMU_TEST_TMP_ROOT:-$(mktemp -d)}"

cleanup() {
    if [ -z "${SMU_TEST_KEEP_TMP:-}" ]; then
        rm -rf "$tmp_root"
    fi
}

if [ -z "${SMU_TEST_TMP_ROOT:-}" ]; then
    trap cleanup EXIT
fi

test_agent_intake_snapshot() {
    local actual="$tmp_root/agent-intake.json"

    "$repo_root/scripts/agent-intake.sh" --json theme > "$actual"
    python3 - "$fixtures_dir/agent-intake-theme.json" "$actual" <<'PY'
import json
import sys

expected = json.load(open(sys.argv[1], encoding="utf-8"))
actual = json.load(open(sys.argv[2], encoding="utf-8"))

assert actual["query"] == expected["query"]
assert expected["matchedIntentsContains"] in actual["matchedIntents"]
paths = {repo["path"] for repo in actual["repositories"]}
assert expected["repositoryPathsContain"] in paths
assert expected["nextCommandsContain"] in actual["nextCommands"]
PY
}

test_health_report_snapshot() {
    local actual="$tmp_root/health-report.json"

    "$repo_root/scripts/health-report.sh" --json > "$actual"
    python3 - "$fixtures_dir/health-report.json" "$actual" <<'PY'
import json
import sys

expected = json.load(open(sys.argv[1], encoding="utf-8"))
actual = json.load(open(sys.argv[2], encoding="utf-8"))

repos = actual["repositories"]
paths = {repo["path"] for repo in repos}
assert expected["repositoriesContain"] in paths
required = set(expected["requiredRepositoryKeys"])
for repo in repos:
    assert required <= set(repo), repo
PY
}

test_release_readiness_snapshot() {
    local actual="$tmp_root/release-readiness.json"

    "$repo_root/scripts/release-install-update.sh" --publish-plan --json > "$actual"
    python3 - "$fixtures_dir/release-readiness.json" "$actual" <<'PY'
import json
import sys

expected = json.load(open(sys.argv[1], encoding="utf-8"))
actual = json.load(open(sys.argv[2], encoding="utf-8"))

assert actual["mode"] == expected["mode"]
assert actual["stage"] == expected["stage"]
assert set(expected["candidateKeys"]) <= set(actual["candidate"])
actions = {item["action"] for item in actual["publish_plan"]}
for action in expected["publishActionsContain"]:
    assert action in actions
PY
}

test_agent_intake_snapshot
test_health_report_snapshot
test_release_readiness_snapshot
