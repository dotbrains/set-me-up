#!/usr/bin/env bash

set -euo pipefail

smu_check_runner_verbose=0
smu_check_runner_passed=0

smu_check_runner_init() {
    smu_check_runner_verbose="$1"
    smu_check_runner_passed=0
}

smu_run_timed_check() {
    local label="$1"
    local timeout_seconds="${SMU_VALIDATE_TIMEOUT:-90}"
    shift

    printf "checking %s\n" "$label"
    set +e
    python3 - "$label" "$timeout_seconds" "$smu_check_runner_verbose" "$@" <<'PY'
import subprocess
import sys

label = sys.argv[1]
timeout_seconds = int(sys.argv[2])
verbose = sys.argv[3] == "1"
command = sys.argv[4:]
try:
    subprocess.run(
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
PY
    local exit_code="$?"
    set -e
    [ "$exit_code" -eq 0 ] || return "$exit_code"
    smu_check_runner_passed=$((smu_check_runner_passed + 1))
}

smu_check_runner_summary() {
    local label="$1"

    printf "%s checks: %s passed, 0 failed\n" "$label" "$smu_check_runner_passed"
}
