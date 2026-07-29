#!/usr/bin/env bash

set -euo pipefail

smu_json_escape() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\t'/\\t}"
    printf "%s" "$value"
}
