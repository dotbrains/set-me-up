# Executable Workflows

These command blocks are validated by `scripts/validate-executable-docs.sh`.
They are intentionally dry-run or read-only surfaces so CI can keep the
documented workflows aligned with the commands users run.

## vps

```bash
INSTALL_URL="https://raw.githubusercontent.com/dotbrains/set-me-up-installer/main/install.sh"
curl -fsSL "$INSTALL_URL" | bash -s -- --profile vps --plan
smu plan --machine vps --json
smu doctor --strict --json
```

## rcm

```bash
smu blueprint init --mode rcm --output smu.toml --force
smu provisioning-adapter preflight --adapter rcm --profile default --json
smu trust enforce --preset personal-laptop --json
```

## nix

```bash
smu blueprint init --mode nix --output smu.toml --force
smu nix doctor --profile default --json
smu nix switch --profile default --dry-run --json
```

## hybrid

```bash
smu blueprint init --mode hybrid --output smu.toml --force
smu provisioning-adapter preflight --adapter home-manager --profile default --json
smu provisioning-adapter plan --adapter home-manager --profile default
```

## release

```bash
scripts/release.sh --check --json
scripts/release.sh --candidate --json
scripts/release.sh --publish --dry-run --json
```

## migration

```bash
smu migration-pr --repo . --mode hybrid --dry-run --json
smu migration-pr --repo . --mode nix --ci-template --badge --dry-run --json
```

## rollback

```bash
smu rollback doctor --json
smu rollback --dry-run
smu plan --machine vps --json
```

## fleet

```bash
smu fleet plan --hosts hosts.txt --profile vps --json
smu fleet plan --profile vps --provisioning-adapter home-manager --json
smu fleet apply --hosts hosts.txt --profile vps --dry-run --parallel 2 --continue-on-error --json
```

## release-package

```bash
smu release-package --version 1.2.3 --channel latest-known-good --json
smu release-package --version 1.2.3 --channel latest-known-good --output dist/set-me-up-1.2.3 --json
smu release-notes --from release-readiness.json --output RELEASE.md
```

## blueprint-registry

```bash
smu blueprint-registry --json
smu blueprint-registry --search dotbrains --json
smu blueprint-registry --registry-url https://example.com/smu-blueprints.json --json
```

## module-graph

```bash
smu module-graph base rcm nix --json
smu plan --machine vps --json
```

## tui

```bash
smu tui --profile vps --json
smu tui --profile vps --provisioning-adapter home-manager --json
```

## drift

```bash
smu drift doctor --json
smu drift doctor --root . --json
```

## post-install

```bash
smu post-install doctor --profile vps --json
smu doctor --strict --json
```

## policy

```bash
smu policy check --preset ci --json
smu policy check --preset strict --provisioning-adapter rcm --json
smu policy check --root . --preset ci --json
```

## rollback-test

```bash
smu rollback-test restore --json
smu rollback doctor --json
```

## product-docs

```bash
smu product-docs generate --source scripts/docs/EXECUTABLE-WORKFLOWS.md --output site/product-docs.md --json
scripts/validate-executable-docs.sh
```
