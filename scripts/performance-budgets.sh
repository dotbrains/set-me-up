#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
budget_seconds="${SMU_PERFORMANCE_BUDGET_SECONDS:-20}"
snapshot="$(mktemp "${TMPDIR:-/tmp}/smu-repo-health.XXXXXX.tsv")"

cleanup() {
    rm -f "$snapshot"
}
trap cleanup EXIT

usage() {
    printf "Usage: %s\n" "$0" >&2
}

case "${1:-}" in
    "")
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 2
        ;;
esac

run_budget() {
    local label="$1"
    shift

    python3 - "$label" "$budget_seconds" "$repo_root" "$snapshot" "$@" <<'PY'
import os
import subprocess
import sys
import time

label = sys.argv[1]
budget = float(sys.argv[2])
repo_root = sys.argv[3]
snapshot = sys.argv[4]
command = sys.argv[5:]
env = os.environ.copy()
env["SMU_REPO_HEALTH_CACHE"] = snapshot

start = time.monotonic()
subprocess.run(command, cwd=repo_root, env=env, check=True, stdout=subprocess.DEVNULL)
elapsed = time.monotonic() - start
if elapsed > budget:
    raise SystemExit(f"{label}: {elapsed:.2f}s exceeded {budget:.2f}s budget")
print(f"{label}: {elapsed:.2f}s")
PY
}

cd "$repo_root"
scripts/repo-health-snapshot.sh --output "$snapshot"
run_budget "doctor json" scripts/doctor.sh --json
run_budget "health report json" scripts/health-report.sh --json
run_budget "sync report json" scripts/sync-report.sh --json
run_budget "capabilities json" scripts/capabilities.sh --json
run_budget "update plan json" scripts/update.sh --plan --json
