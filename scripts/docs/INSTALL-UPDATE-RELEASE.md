# Install And Update Release Checklist

Use this checklist when changing the blueprint bootstrap, installer update
commands, or scenario tests that fetch the installer from GitHub.

## Release Order

1. Ship `set-me-up-installer`.
2. Ship `set-me-up-blueprint` docs or bootstrap-template changes.
3. Ship `set-me-up-tests`.
4. Run scenario tests against the published installer ref.

`set-me-up-tests` fetches the installer from GitHub during scenario runs. Test
changes that assert new installer behavior should either use
`SMU_INSTALLER_REF` / `SMU_INSTALLER_URL` for candidate validation or be pushed
after the installer branch that contains the behavior is available.

## Candidate Validation

From `tests/`, validate an unpublished installer branch before merging:

```bash
SMU_PASS_HOST_ENV=true SMU_INSTALLER_REF=my-branch ./scripts/run-scenario.sh default
```

Use `SMU_INSTALLER_URL` instead when testing a fork or nonstandard raw URL.

## Local Validation

Run the native validator in every changed child repo:

```bash
scripts/release-install-update.sh --check
```

This runs the child validators in release order. To run them manually:

```bash
(cd installer && scripts/validate.sh --all)
(cd blueprint && scripts/validate.sh)
(cd tests && scripts/validate.sh)
```

After child commits are ready, push them in release order:

```bash
scripts/release-install-update.sh --push
```

When root files changed, also run:

```bash
scripts/validate.sh --all
```

## Manual Smoke

For a real installed checkout, verify:

```bash
INSTALL_URL="https://raw.githubusercontent.com/<OWNER>/<BLUEPRINT>/<BRANCH>/dotfiles/modules/install.sh"
bash <(curl -s -L "$INSTALL_URL") --plan
smu update doctor --json
smu update blueprint --dry-run
smu update installer --dry-run
smu update modules --dry-run
smu update --all --dry-run
```

If a checkout is dirty, `smu update doctor --json` should report that
`--force-reset` would be required. Do not use `--force-reset` unless local
changes should be discarded.
