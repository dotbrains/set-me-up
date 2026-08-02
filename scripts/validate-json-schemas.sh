#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf "Usage: %s\n" "$0" >&2
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        usage
        exit 2
        ;;
esac

cd "$repo_root"

python3 - "$repo_root" <<'PY'
import json
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])

checks = [
    ("health-report.schema.json", ["scripts/health-report.sh", "--json"], False, 90),
    ("doctor.schema.json", ["scripts/doctor.sh", "--json"], False, 90),
    ("freshness-report.schema.json", ["scripts/freshness-report.sh", "--json"], False, 30),
    ("change-report.schema.json", ["scripts/change-report.sh", "--json"], False, 30),
    ("ci-workflow-report.schema.json", ["scripts/ci-workflow-report.sh", "--checked-out", "--json"], False, 30),
    ("native-workflow-template.schema.json", ["scripts/native-workflow-template.sh", "--check", "--json"], False, 30),
    ("capabilities.schema.json", ["scripts/capabilities.sh", "--json"], False, 90),
    ("agent-intake.schema.json", ["scripts/agent-intake.sh", "--json", "theme"], False, 90),
    ("sync-report.schema.json", ["scripts/sync-report.sh", "--json"], False, 90),
    ("update-report.schema.json", ["scripts/update.sh", "--plan", "--json"], False, 90),
    ("release-readiness.schema.json", ["scripts/release-install-update.sh", "--publish-plan", "--json"], False, 30),
]


def type_matches(value, expected):
    if isinstance(expected, list):
        return any(type_matches(value, item) for item in expected)
    return {
        "array": isinstance(value, list),
        "boolean": isinstance(value, bool),
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "object": isinstance(value, dict),
        "string": isinstance(value, str),
    }.get(expected, True)


def validate(schema, value, path):
    if "type" in schema and not type_matches(value, schema["type"]):
        raise SystemExit(f"{path}: expected {schema['type']}")
    if "enum" in schema and value not in schema["enum"]:
        raise SystemExit(f"{path}: unexpected value {value!r}")
    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                raise SystemExit(f"{path}: missing required key {key}")
        properties = schema.get("properties", {})
        if schema.get("additionalProperties") is False:
            extra = set(value) - set(properties)
            if extra:
                raise SystemExit(f"{path}: unexpected keys {sorted(extra)}")
        for key, child_schema in properties.items():
            if key in value:
                validate(child_schema, value[key], f"{path}.{key}")
    if isinstance(value, list) and "items" in schema:
        for index, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{index}]")


for schema_name, command, allow_failure_payload, timeout_seconds in checks:
    schema_path = root / "scripts" / "schemas" / schema_name
    schema = json.loads(schema_path.read_text())
    print(f"checking {schema_name} via {' '.join(command)}")
    try:
        payload_text = subprocess.check_output(
            command,
            cwd=root,
            text=True,
            stderr=subprocess.STDOUT,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as exc:
        raise SystemExit(
            f"{schema_name}: command timed out: {' '.join(command)}"
        ) from exc
    except subprocess.CalledProcessError as exc:
        if allow_failure_payload:
            payload_text = exc.output
        else:
            raise SystemExit(
                f"{schema_name}: command failed: {' '.join(command)}\n{exc.output}"
            ) from exc
    payload = json.loads(payload_text)
    validate(schema, payload, schema_name)

print("JSON schema checks passed.")
PY
