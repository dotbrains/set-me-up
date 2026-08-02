#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---check}"

usage() {
    printf "Usage: %s [--write|--check]\n" "$0" >&2
}

case "$mode" in
    --write | --check)
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

cd "$repo_root"

python3 - "$mode" <<'PY'
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

mode = sys.argv[1]
fixtures = {
    "theme": Path("scripts/tests/fixtures/agent-intake-theme.json"),
    "prompt": Path("scripts/tests/fixtures/agent-intake-prompt.json"),
    "new repo": Path("scripts/tests/fixtures/agent-intake-new-repo.json"),
}


def normalize(payload):
    first = payload["repositories"][0]
    return {
        "query": payload["query"],
        "matchedIntents": payload["matchedIntents"],
        "ambiguities": payload["ambiguities"],
        "firstRepository": {
            key: first[key]
            for key in ["path", "role", "confidence", "score", "source"]
        },
        "nextCommands": payload["nextCommands"],
    }


with tempfile.NamedTemporaryFile() as cache:
    snapshot = subprocess.check_output(
        ["bash", "scripts/repo-health-snapshot.sh"],
        text=True,
        timeout=90,
    )
    cache.write(snapshot.encode())
    cache.flush()
    env = {**os.environ, "SMU_REPO_HEALTH_CACHE": cache.name}

    for query, fixture_path in fixtures.items():
        payload = json.loads(subprocess.check_output(
            ["bash", "scripts/agent-intake.sh", "--json", query],
            text=True,
            timeout=30,
            env=env,
        ))
        normalized = normalize(payload)
        if mode == "--write":
            fixture_path.write_text(json.dumps(normalized, indent=2) + "\n")
            continue

        expected = json.loads(fixture_path.read_text())
        if normalized != expected:
            raise SystemExit(
                f"{fixture_path} mismatch\n"
                f"expected={json.dumps(expected, indent=2)}\n"
                f"actual={json.dumps(normalized, indent=2)}"
            )

print("Agent intake fixtures passed.")
PY
