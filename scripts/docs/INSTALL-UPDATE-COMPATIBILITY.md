# Install And Update Compatibility Matrix

<!-- markdownlint-disable MD013 -->

This matrix records the combinations expected to pass before an installer,
blueprint, or scenario-test release is considered ready.

| Installer ref | Blueprint ref | Scenario | Environment | Required check |
| --- | --- | --- | --- | --- |
| `main` | `dotbrains/set-me-up-blueprint@master` | `default` | Docker Linux | `scripts/release-install-update.sh --check` |
| `main` | `nicholasadamou/dotfiles@main` | `dotfiles` | Docker Linux | `scripts/release-install-update.sh --check` |
| `main` | `nicholasadamou/dotfiles@main` | `dotfiles-macos` | macOS native | Manual or GitHub Actions scenario run |
| `candidate` | `dotbrains/set-me-up-blueprint@master` | `default` | Docker Linux | `SMU_INSTALLER_REF=candidate` scenario run |

## Candidate Channel

The installer repository keeps `main` as the stable channel. Maintainers may
publish the latest validated installer commit to the `candidate` branch with:

```bash
scripts/release-install-update.sh --push --candidate candidate
```

Consumers can test the candidate channel without changing the stable install
URL:

```bash
SMU_INSTALLER_REF=candidate bash <(curl -sSL https://raw.githubusercontent.com/dotbrains/set-me-up-installer/main/install.sh) --plan --json
```

Use a fully custom installer source when validating a fork:

```bash
SMU_INSTALLER_URL="https://raw.githubusercontent.com/<OWNER>/<REPO>/<REF>/install.sh" \
  bash <(curl -sSL "$SMU_INSTALLER_URL") --plan --json
```

## Release Tags

Installer releases should be tagged only after the release readiness check
passes:

```bash
scripts/release-install-update.sh --check --json
scripts/release-install-update.sh --push --tag vX.Y.Z --candidate candidate
```
