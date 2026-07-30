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
    ("health-report.schema.json", ["scripts/health-report.sh", "--json"]),
    ("doctor.schema.json", ["scripts/doctor.sh", "--json"]),
    ("freshness-report.schema.json", ["scripts/freshness-report.sh", "--json"]),
    ("change-report.schema.json", ["scripts/change-report.sh", "--json"]),
    ("ci-workflow-report.schema.json", ["scripts/ci-workflow-report.sh", "--checked-out", "--json"]),
    ("native-workflow-template.schema.json", ["scripts/native-workflow-template.sh", "--check", "--json"]),
    ("capabilities.schema.json", ["scripts/capabilities.sh", "--json"]),
    ("agent-intake.schema.json", ["scripts/agent-intake.sh", "--json", "theme"]),
    ("sync-report.schema.json", ["scripts/sync-report.sh", "--json"]),
    ("update-report.schema.json", ["scripts/update.sh", "--plan", "--json"]),
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


for schema_name, command in checks:
    schema_path = root / "scripts" / "schemas" / schema_name
    schema = json.loads(schema_path.read_text())
    print(f"checking {schema_name} via {' '.join(command)}")
    try:
        payload_text = subprocess.check_output(
            command,
            cwd=root,
            text=True,
            stderr=subprocess.STDOUT,
            timeout=30,
        )
    except subprocess.TimeoutExpired as exc:
        raise SystemExit(
            f"{schema_name}: command timed out: {' '.join(command)}"
        ) from exc
    except subprocess.CalledProcessError as exc:
        raise SystemExit(
            f"{schema_name}: command failed: {' '.join(command)}\n{exc.output}"
        ) from exc
    payload = json.loads(payload_text)
    validate(schema, payload, schema_name)

print("JSON schema checks passed.")
PY
