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
