#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    printf "Usage: %s [--check|--candidate|--publish] [release-install-update args...]\n" "$0" >&2
}

mode="${1:---check}"
case "$mode" in
    --check | --candidate | --publish)
        shift || true
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

case "$mode" in
    --check)
        exec "$repo_root/scripts/release-install-update.sh" --check "$@"
        ;;
    --candidate)
        exec "$repo_root/scripts/release-install-update.sh" --candidate-promote "$@"
        ;;
    --publish)
        exec "$repo_root/scripts/release-install-update.sh" --push "$@"
        ;;
esac
