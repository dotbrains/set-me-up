#!/usr/bin/env bash

set -euo pipefail

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/tests" && pwd)"

"$test_dir/test-setup-update.sh"
"$test_dir/test-manifests.sh"
"$test_dir/test-routes-doctor.sh"

printf "Root script tests passed.\n"
