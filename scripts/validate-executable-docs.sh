#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/scripts/docs/EXECUTABLE-WORKFLOWS.md"

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

require_workflow() {
    local id="$1"
    local command="$2"

    grep -q "^## $id$" "$manifest" || {
        printf "Missing executable workflow section: %s\n" "$id" >&2
        return 1
    }
    grep -Fq "$command" "$manifest" || {
        printf "Missing executable workflow command for %s: %s\n" "$id" "$command" >&2
        return 1
    }
}

cd "$repo_root"
[ -f "$manifest" ] || {
    printf "Missing executable workflow manifest: %s\n" "$manifest" >&2
    exit 1
}

require_workflow "vps" "smu plan --machine vps --json"
require_workflow "rcm" "smu provisioning-adapter preflight --adapter rcm --profile default --json"
require_workflow "nix" "smu nix doctor --profile default --json"
require_workflow "hybrid" "smu provisioning-adapter preflight --adapter home-manager --profile default --json"
require_workflow "release" "scripts/release.sh --check --json"
require_workflow "migration" "smu migration-pr --repo . --mode hybrid --dry-run --json"
require_workflow "rollback" "smu rollback doctor --json"
require_workflow "fleet" "smu fleet plan --hosts hosts.txt --profile vps --json"
require_workflow "release-package" "smu release-package --version 1.2.3 --channel latest-known-good --json"
require_workflow "blueprint-registry" "smu blueprint-registry --json"
require_workflow "module-graph" "smu module-graph base rcm nix --json"
require_workflow "tui" "smu tui --profile vps --json"
require_workflow "drift" "smu drift doctor --json"
require_workflow "post-install" "smu post-install doctor --profile vps --json"
require_workflow "policy" "smu policy check --preset ci --json"
require_workflow "rollback-test" "smu rollback-test restore --json"
require_workflow "product-docs" "smu product-docs generate --output site/product-docs.md --json"

awk '
    /^```bash$/ { in_block = 1; next }
    /^```$/ && in_block { in_block = 0; next }
    in_block && $0 !~ /^#/ && $0 !~ /^$/ { print }
' "$manifest" | bash -n

printf "Executable docs workflows passed.\n"
