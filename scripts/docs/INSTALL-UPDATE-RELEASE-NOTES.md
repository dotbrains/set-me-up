# Install And Update Release Notes Template

<!-- markdownlint-disable MD013 -->

Use this template when creating an installer GitHub Release.

## Summary

- Installer tag:
- Installer commit:
- Candidate branch:
- Blueprint commit:
- Tests commit:

## Compatibility Matrix

| Scenario | Environment | Installer ref | Blueprint ref | Result |
| --- | --- | --- | --- | --- |
| `default` | Docker Linux | | | |
| `dotfiles` | Docker Linux | | | |
| `dotfiles-macos` | macOS native | | | |

## Readiness

```bash
scripts/release-install-update.sh --check --json
scripts/release-install-update.sh --candidate-check --json
scripts/release-install-update.sh --publish-plan --json --tag vX.Y.Z --candidate candidate
```

## Rollback

- Stable installer URL:
- Previous installer tag:
- Candidate reset command, if needed:

```bash
git -C installer push origin <previous-good-sha>:refs/heads/candidate
```

## Known Risks

- None documented.
