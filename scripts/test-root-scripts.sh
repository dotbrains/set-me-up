#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/tests" && pwd)"

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

"$test_dir/test-setup-update.sh"
"$test_dir/test-manifests.sh"
"$test_dir/test-routes-doctor.sh"
"$test_dir/test-lib-modules.sh"
"$test_dir/test-output-snapshots.sh"

printf "Root script tests passed.\n"
