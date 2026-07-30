# Install And Update Release Checklist

<!-- markdownlint-disable MD013 -->

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

The stable installer channel is `main`. Maintainers can publish a validated
candidate channel from the current installer commit:

```bash
scripts/release-install-update.sh --push --candidate candidate
```

Protect the `candidate` branch in GitHub so only maintainers can update it, and
update it through this helper. That keeps the candidate channel tied to the same
release-readiness checks as `main`.

Users and CI can then test that channel with:

```bash
SMU_INSTALLER_REF=candidate bash <(curl -sSL https://raw.githubusercontent.com/dotbrains/set-me-up-installer/main/install.sh) --plan --json
```

## Local Validation

Run the native validator in every changed child repo:

```bash
scripts/release-install-update.sh --check
scripts/release-install-update.sh --check --json
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
scripts/release-install-update.sh --push --tag vX.Y.Z --candidate candidate
scripts/release-install-update.sh --push --tag vX.Y.Z --signed-tag --github-release
```

Use `--signed-tag` when local GPG signing is configured. Use `--github-release`
to create a GitHub Release in `dotbrains/set-me-up-installer`; omit
`--release-notes` to let GitHub generate notes, or pass explicit notes for a
manual release summary.

Preview the publish actions without rerunning validators or mutating remotes:

```bash
scripts/release-install-update.sh --publish-plan --json --tag vX.Y.Z --candidate candidate --github-release
```

Check whether the remote candidate branch already points at installer `main`:

```bash
scripts/release-install-update.sh --candidate-check --json
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

## Rollback

If a candidate install or update is wrong, inspect the local state first:

```bash
smu update doctor --json
smu update --plan --json
```

For dirty checkouts, commit or stash local work before trying another update.
Use `--force-reset` only when the local work can be discarded. To return the
installer to the stable channel, rerun the stable install command without
`SMU_INSTALLER_REF` or `SMU_INSTALLER_URL`.

## Compatibility

Keep the release matrix current when scenarios, supported channels, or operating
systems change:

```text
scripts/docs/INSTALL-UPDATE-COMPATIBILITY.md
```

## Failure Payloads

Automation should call the helper with `--json`. On failure it emits the stage
that failed, for example `validate:installer`, `clean:tests`, or
`release:github`, then exits non-zero. The JSON contract is validated by:

```bash
scripts/validate-json-schemas.sh
```
