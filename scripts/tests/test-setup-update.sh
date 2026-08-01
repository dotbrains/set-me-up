#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=scripts/tests/test-helpers.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-helpers.sh"

: "$repo_root" "$tmp_root"


test_piped_setup_resolves_cloned_manifest() {
    local work_dir="$tmp_root/piped"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    mkdir -p "$work_dir"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash < "$repo_root/scripts/setup.sh" > "$output"
    )

    assert_file "$work_dir/set-me-up/scripts/repos.txt"
    assert_contains "$output" "Cloning set-me-up repository"
}

test_piped_setup_ignores_unrelated_git_repo() {
    local work_dir="$tmp_root/unrelated/work"
    local bin_dir="$tmp_root/unrelated/bin"
    local output="$tmp_root/unrelated/output.log"

    mkdir -p "$work_dir/.git"
    touch "$work_dir/README.md"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash < "$repo_root/scripts/setup.sh" > "$output"
    )

    assert_file "$work_dir/set-me-up/scripts/repos.txt"
    assert_contains "$output" "Cloning set-me-up repository"
}

test_setup_propagates_clone_failures() {
    local work_dir="$tmp_root/clone-failure/set-me-up"
    local bin_dir="$tmp_root/clone-failure/bin"
    local output="$tmp_root/clone-failure/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/.git"
    printf "fail-repo|fail|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    if (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash scripts/setup.sh > "$output" 2>&1
    ); then
        fail "setup.sh succeeded after clone failure"
    fi

    assert_contains "$output" "clone failed"
}

test_update_plans_skips_and_current_repos() {
    local work_dir="$tmp_root/update"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
EOF
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_REPO_ROOT="$repo_root" PATH="$bin_dir:$PATH" \
            bash scripts/update.sh --plan > "$output"
    )

    assert_contains "$output" "path"
    assert_contains "$output" "clean"
    assert_contains "$output" "current"
    assert_contains "$output" "skip-dirty"
    assert_contains "$output" "skip-missing"
}

test_update_outputs_json_plan() {
    local work_dir="$tmp_root/update-json"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/update.sh --plan --json > "$output"
    )

    assert_contains "$output" '"repositories":['
    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"action":"current"'
}

test_update_json_plan_reports_repo_states() {
    local work_dir="$tmp_root/update-json-states"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git" "$work_dir/dirty/.git" "$work_dir/not-git"
    touch "$work_dir/dirty/.dirty"
    cat > "$work_dir/scripts/repos.txt" <<'EOF'
clean|clean|top-level
dirty|dirty|top-level
missing|missing|top-level
not-git|not-git|top-level
EOF
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        PATH="$bin_dir:$PATH" bash scripts/update.sh --plan --json > "$output"
    )

    assert_contains "$output" '"path":"clean"'
    assert_contains "$output" '"action":"current"'
    assert_contains "$output" '"path":"dirty"'
    assert_contains "$output" '"action":"skip-dirty"'
    assert_contains "$output" '"path":"missing"'
    assert_contains "$output" '"action":"skip-missing"'
    assert_contains "$output" '"path":"not-git"'
    assert_contains "$output" '"action":"skip-not-git"'
}

test_update_json_plan_does_not_fetch() {
    local work_dir="$tmp_root/update-json-no-fetch"
    local bin_dir="$work_dir/bin"
    local output="$work_dir/output.json"
    local fetch_log="$work_dir/fetch.log"

    copy_root_scripts "$work_dir"
    mkdir -p "$work_dir/clean/.git"
    printf "clean|clean|top-level\\n" > "$work_dir/scripts/repos.txt"
    install_mock_git "$bin_dir"

    (
        cd "$work_dir"
        SMU_TEST_GIT_FETCH_LOG="$fetch_log" PATH="$bin_dir:$PATH" \
            bash scripts/update.sh --plan --json > "$output"
    )

    [ ! -f "$fetch_log" ] || fail "update plan mode unexpectedly fetched"
    assert_contains "$output" '"path":"clean"'
}

copy_release_script_fixture() {
    local work_dir="$1"

    mkdir -p "$work_dir/scripts/lib"
    cp "$repo_root/scripts/release-install-update.sh" "$work_dir/scripts/"
    cp "$repo_root/scripts/lib/json.sh" "$work_dir/scripts/lib/"
    cp "$repo_root/scripts/lib/repo-health.sh" "$work_dir/scripts/lib/"
    cp "$repo_root/scripts/lib/release-readiness-render.sh" "$work_dir/scripts/lib/"
}

write_release_preflight_fixture() {
    local work_dir="$1"

    mkdir -p "$work_dir/installer/docs/json-contracts"
    cat > "$work_dir/installer/docs/json-contracts/provisioning-preflight.example.json" <<'EOF'
{
  "adapter": "rcm",
  "action": "install",
  "host_supported": true,
  "can_apply": false,
  "preflight": "passed",
  "plan": { "commands": [] },
  "errors": []
}
EOF
    cat > "$work_dir/installer/docs/json-contracts/provisioning-capabilities.example.json" <<'EOF'
{
  "contract": {
    "version": 1,
    "blueprint_keys": ["provisioning.mode", "provisioning.adapter", "provisioning.nix_adapter"],
    "module_manifest_table": "adapters",
    "module_adapter_required_keys": ["path"]
  },
  "adapters": [
    { "id": "rcm" },
    { "id": "home-manager" },
    { "id": "nix-darwin" },
    { "id": "nixos" },
    { "id": "hybrid" }
  ]
}
EOF
    cat > "$work_dir/installer/smu.py" <<'EOF'
#!/usr/bin/env python3
import json
import sys

command = sys.argv[2]
name = sys.argv[3]

if command == "schema":
    print(json.dumps({
        "$id": f"https://dotbrains.dev/set-me-up/contracts/{name}.schema.json",
        "type": "object",
    }))
    sys.exit(0)

path = sys.argv[sys.argv.index("--path") + 1]
payload = json.load(sys.stdin if path == "-" else open(path, encoding="utf-8"))
errors = []

if name == "provisioning-preflight":
    for key in ("adapter", "action", "host_supported", "can_apply", "preflight", "plan", "errors"):
        if key not in payload:
            errors.append(f"missing {key}")
    if not isinstance(payload.get("plan", {}).get("commands"), list):
        errors.append("plan.commands must be an array")
elif name == "provisioning-capabilities":
    contract = payload.get("contract", {})
    adapters = {adapter.get("id") for adapter in payload.get("adapters", [])}
    if contract.get("version") != 1:
        errors.append("contract.version must be 1")
    if contract.get("module_manifest_table") != "adapters":
        errors.append("module_manifest_table must be adapters")
    if "path" not in contract.get("module_adapter_required_keys", []):
        errors.append("module_adapter_required_keys missing path")
    for adapter_id in ("rcm", "home-manager", "nix-darwin", "nixos", "hybrid"):
        if adapter_id not in adapters:
            errors.append(f"missing {adapter_id}")
elif name == "blueprint-ci-readiness":
    readiness = payload.get("readiness", {})
    summary = readiness.get("summary", {})
    if readiness.get("preflight") != "passed":
        errors.append("preflight must be passed")
    if summary.get("workflow_preflight") != 3:
        errors.append("workflow_preflight must be 3")
    if summary.get("provider_examples") != 6:
        errors.append("provider_examples must be 6")
else:
    errors.append(f"unknown contract {name}")

for error in errors:
    print(error, file=sys.stderr)
sys.exit(1 if errors else 0)
EOF
    chmod +x "$work_dir/installer/smu.py"
    mkdir -p "$work_dir/blueprint/examples/github-actions"
    local workflow
    for workflow in rcm nix hybrid; do
        cat > "$work_dir/blueprint/examples/github-actions/$workflow.yml" <<'EOF'
name: test
jobs:
  validate:
    steps:
      - run: python3 set-me-up-installer/smu.py provisioning-adapter preflight --json
EOF
    done
    mkdir -p "$work_dir/blueprint/scripts"
    cat > "$work_dir/blueprint/scripts/validate-examples.sh" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{
  "valid": true,
  "errors": [],
  "readiness": {
    "preflight": "passed",
    "summary": {
      "provider_examples": 6,
      "workflow_preflight": 3
    }
  }
}
JSON
EOF
    chmod +x "$work_dir/blueprint/scripts/validate-examples.sh"
}

test_release_check_outputs_json_readiness() {
    local work_dir="$tmp_root/release-json"
    local output="$work_dir/output.json"

    copy_release_script_fixture "$work_dir"

    local path
    for path in installer blueprint tests; do
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" init --quiet
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
    done

    (
        cd "$work_dir"
        bash scripts/release-install-update.sh --check --json --tag v0.0.0 \
            --candidate candidate --signed-tag --github-release > "$output"
    )

    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "check"
assert payload["stage"] == "complete"
assert payload["candidate"]["ref"] == "candidate"
assert payload["release"]["tag"] == "v0.0.0"
assert payload["release"]["signed"] is True
assert payload["release"]["github_release"] is True
assert payload["release"]["notes_file"] == ""
assert payload["dry_run"] is False
assert payload["provenance"]["installer"] != ""
assert payload["provenance"]["blueprint"] != ""
assert payload["provenance"]["tests"] != ""
assert payload["validated"] is True
assert payload["preflight_contracts"] is True
assert [contract["name"] for contract in payload["contracts"]] == [
    "provisioning-preflight",
    "provisioning-capabilities",
    "blueprint-ci-readiness",
]
assert all(contract["version"] == 1 for contract in payload["contracts"])
assert all(contract["validator"] == "installer/smu.py contract validate" for contract in payload["contracts"])
assert payload["pushed"] is False
assert payload["tagged"] is True
assert payload["failed"] == 0
assert [repo["path"] for repo in payload["repositories"]] == ["installer", "blueprint", "tests"]
PY
}

test_release_failure_outputs_json_stage() {
    local work_dir="$tmp_root/release-json-failure"
    local output="$work_dir/output.json"

    copy_release_script_fixture "$work_dir"

    local path
    for path in installer blueprint tests; do
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$(basename "$(pwd)")" != "blueprint" ]
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        git -C "$work_dir/$path" init --quiet
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
    done

    if (
        cd "$work_dir"
        bash scripts/release-install-update.sh --check --json > "$output"
    ); then
        fail "release readiness succeeded after a child validator failed"
    fi

    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "check"
assert payload["stage"] == "validate:blueprint"
assert payload["validated"] is False
assert payload["failed"] != 0
PY
}

test_release_contract_drift_outputs_json_stage() {
    local work_dir="$tmp_root/release-contract-drift"
    local output="$work_dir/output.json"

    copy_release_script_fixture "$work_dir"

    local path
    for path in installer blueprint tests; do
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" init --quiet
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
    done

    python3 - "$work_dir/installer/docs/json-contracts/provisioning-capabilities.example.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    payload = json.load(handle)
payload["adapters"] = [adapter for adapter in payload["adapters"] if adapter["id"] != "home-manager"]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY
    git -C "$work_dir/installer" add docs/json-contracts/provisioning-capabilities.example.json
    git -C "$work_dir/installer" commit --quiet -m "contract drift"

    if (
        cd "$work_dir"
        bash scripts/release-install-update.sh --check --json > "$output"
    ); then
        fail "release readiness succeeded after provisioning capabilities drift"
    fi

    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "check"
assert payload["stage"] == "preflight-contracts:capabilities"
assert payload["preflight_contracts"] is False
assert payload["failed"] != 0
PY
}

test_release_publish_plan_outputs_actions() {
    local work_dir="$tmp_root/release-publish-plan"
    local output="$work_dir/output.json"

    copy_release_script_fixture "$work_dir"

    local path
    for path in installer blueprint tests; do
        mkdir -p "$work_dir/$path"
        git -C "$work_dir/$path" init --quiet
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        touch "$work_dir/$path/README.md"
        git -C "$work_dir/$path" add README.md
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
    done

    (
        cd "$work_dir"
        bash scripts/release-install-update.sh --publish-plan --json \
            --tag v0.0.0 --candidate candidate --github-release > "$output"
    )

    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

actions = {(item["action"], item["target"], item["detail"]) for item in payload["publish_plan"]}
assert payload["mode"] == "publish-plan"
assert payload["stage"] == "publish-plan"
assert payload["validated"] is False
assert ("push", "installer", "main") in actions
assert ("candidate", "installer", "candidate") in actions
assert ("tag", "installer", "v0.0.0") in actions
assert ("github-release", "installer", "v0.0.0") in actions
PY
}

test_release_candidate_check_fails_when_stale() {
    local work_dir="$tmp_root/release-candidate-stale"
    local output="$work_dir/output.json"
    local remote_dir="$work_dir/remotes"

    mkdir -p "$remote_dir"
    copy_release_script_fixture "$work_dir"

    local path branch
    for path in installer blueprint tests; do
        branch="main"
        [ "$path" = "blueprint" ] && branch="master"
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        git -C "$work_dir/$path" init --quiet --initial-branch "$branch"
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
        git init --quiet --bare "$remote_dir/$path.git"
        git -C "$work_dir/$path" remote add origin "$remote_dir/$path.git"
        git -C "$work_dir/$path" push --quiet -u origin "$branch"
    done
    git -C "$work_dir/installer" push --quiet origin HEAD:refs/heads/candidate
    touch "$work_dir/installer/next"
    git -C "$work_dir/installer" add next
    git -C "$work_dir/installer" commit --quiet -m "new installer"

    if (
        cd "$work_dir"
        bash scripts/release-install-update.sh --candidate-check --json > "$output"
    ); then
        fail "candidate freshness check succeeded while candidate was stale"
    fi

    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "candidate-check"
assert payload["stage"] == "candidate:freshness"
assert payload["candidate"]["fresh"] is False
assert payload["failed"] != 0
PY
}

test_release_github_release_uses_gh_cli() {
    local work_dir="$tmp_root/release-gh"
    local bin_dir="$work_dir/bin"
    local remote_dir="$work_dir/remotes"
    local output="$work_dir/output.json"
    local gh_log="$work_dir/gh.log"

    mkdir -p "$bin_dir" "$remote_dir"
    copy_release_script_fixture "$work_dir"
    cat > "$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*" >> "$SMU_TEST_GH_LOG"
EOF
    chmod +x "$bin_dir/gh"

    local path branch
    for path in installer blueprint tests; do
        branch="main"
        [ "$path" = "blueprint" ] && branch="master"
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        git -C "$work_dir/$path" init --quiet --initial-branch "$branch"
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
        git init --quiet --bare "$remote_dir/$path.git"
        git -C "$work_dir/$path" remote add origin "$remote_dir/$path.git"
        git -C "$work_dir/$path" push --quiet -u origin "$branch"
    done

    (
        cd "$work_dir"
        SMU_TEST_GH_LOG="$gh_log" PATH="$bin_dir:$PATH" \
            bash scripts/release-install-update.sh --push --json \
            --candidate "" --tag v0.0.1 --github-release \
            --release-title "Installer v0.0.1" \
            --release-notes "Release notes" > "$output"
    )

    assert_contains "$gh_log" "release create v0.0.1 --repo dotbrains/set-me-up-installer --title Installer v0.0.1 --notes Release notes"
    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "push"
assert payload["stage"] == "complete"
assert payload["release"]["github_release"] is True
assert payload["tagged"] is True
assert payload["failed"] == 0
PY
}

test_release_dry_run_push_does_not_mutate_remotes() {
    local work_dir="$tmp_root/release-dry-run"
    local remote_dir="$work_dir/remotes"
    local output="$work_dir/output.json"

    mkdir -p "$remote_dir"
    copy_release_script_fixture "$work_dir"

    local path branch
    for path in installer blueprint tests; do
        branch="main"
        [ "$path" = "blueprint" ] && branch="master"
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        git -C "$work_dir/$path" init --quiet --initial-branch "$branch"
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
        git init --quiet --bare "$remote_dir/$path.git"
        git -C "$work_dir/$path" remote add origin "$remote_dir/$path.git"
        git -C "$work_dir/$path" push --quiet -u origin "$branch"
    done

    (
        cd "$work_dir"
        bash scripts/release-install-update.sh --push --dry-run --json \
            --tag v0.0.2 --candidate candidate --github-release > "$output"
    )

    if git -C "$remote_dir/installer.git" rev-parse refs/tags/v0.0.2 >/dev/null 2>&1; then
        fail "dry-run unexpectedly pushed a tag"
    fi
    if git -C "$remote_dir/installer.git" rev-parse refs/heads/candidate >/dev/null 2>&1; then
        fail "dry-run unexpectedly pushed candidate"
    fi
    python3 - "$output" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "push"
assert payload["dry_run"] is True
assert payload["validated"] is True
assert payload["pushed"] is False
assert payload["tagged"] is True
PY
}

test_release_notes_file_and_release_mode_use_gh_cli() {
    local work_dir="$tmp_root/release-notes-file"
    local bin_dir="$work_dir/bin"
    local remote_dir="$work_dir/remotes"
    local output="$work_dir/output.json"
    local gh_log="$work_dir/gh.log"
    local notes_file="$work_dir/notes.md"

    mkdir -p "$bin_dir" "$remote_dir"
    copy_release_script_fixture "$work_dir"
    printf "Release notes from file\n" > "$notes_file"
    cat > "$bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
printf "%s\n" "$*" >> "$SMU_TEST_GH_LOG"
EOF
    chmod +x "$bin_dir/gh"

    local path branch
    for path in installer blueprint tests; do
        branch="main"
        [ "$path" = "blueprint" ] && branch="master"
        mkdir -p "$work_dir/$path/scripts"
        cat > "$work_dir/$path/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
        chmod +x "$work_dir/$path/scripts/validate.sh"
        git -C "$work_dir/$path" init --quiet --initial-branch "$branch"
        git -C "$work_dir/$path" config user.name "set-me-up test"
        git -C "$work_dir/$path" config user.email "set-me-up@example.test"
        git -C "$work_dir/$path" config commit.gpgsign false
        git -C "$work_dir/$path" config tag.gpgsign false
        write_release_preflight_fixture "$work_dir"
        git -C "$work_dir/$path" add .
        git -C "$work_dir/$path" commit --quiet -m "test fixture"
        git init --quiet --bare "$remote_dir/$path.git"
        git -C "$work_dir/$path" remote add origin "$remote_dir/$path.git"
        git -C "$work_dir/$path" push --quiet -u origin "$branch"
    done

    (
        cd "$work_dir"
        SMU_TEST_GH_LOG="$gh_log" PATH="$bin_dir:$PATH" \
            bash scripts/release-install-update.sh --release v0.0.3 --json \
            --candidate "" --notes-file "$notes_file" > "$output"
    )

    assert_contains "$gh_log" "release create v0.0.3 --repo dotbrains/set-me-up-installer --title set-me-up installer v0.0.3 --notes Release notes from file"
    python3 - "$output" "$notes_file" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

assert payload["mode"] == "push"
assert payload["release"]["tag"] == "v0.0.3"
assert payload["release"]["github_release"] is True
assert payload["release"]["notes_file"] == sys.argv[2]
assert payload["pushed"] is True
PY
}


if [ "${SMU_RELEASE_HELPER_SELF_TEST:-}" = 1 ]; then
    test_release_check_outputs_json_readiness
    test_release_failure_outputs_json_stage
    test_release_publish_plan_outputs_actions
    test_release_candidate_check_fails_when_stale
    test_release_github_release_uses_gh_cli
    test_release_dry_run_push_does_not_mutate_remotes
    test_release_notes_file_and_release_mode_use_gh_cli
else
    test_piped_setup_resolves_cloned_manifest
    test_piped_setup_ignores_unrelated_git_repo
    test_setup_propagates_clone_failures
    test_update_plans_skips_and_current_repos
    test_update_outputs_json_plan
    test_update_json_plan_reports_repo_states
    test_update_json_plan_does_not_fetch
    test_release_check_outputs_json_readiness
    test_release_failure_outputs_json_stage
    test_release_publish_plan_outputs_actions
    test_release_candidate_check_fails_when_stale
    test_release_github_release_uses_gh_cli
    test_release_dry_run_push_does_not_mutate_remotes
    test_release_notes_file_and_release_mode_use_gh_cli
fi
