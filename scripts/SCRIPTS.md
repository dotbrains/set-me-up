# Scripts Documentation

This document describes the setup and update scripts used to manage the
set-me-up repository collection.

Detailed setup, update, troubleshooting, and maintenance notes live in
[SCRIPTS-DETAILS.md](docs/SCRIPTS-DETAILS.md). Generated command usage lives in
[COMMANDS.md](docs/COMMANDS.md). Install/update release ordering lives in
[INSTALL-UPDATE-RELEASE.md](docs/INSTALL-UPDATE-RELEASE.md).

## Overview

The set-me-up project consists of multiple repositories organized in a specific
directory structure. These scripts help manage these repositories:

- **`setup.sh`**: Initial cloning of all repositories
- **`update.sh`**: Updating existing repositories
- **`validate-repos.sh`**: Running validators across clean child repositories
- **`agent-intake.sh`**: Agent task intake that joins intents, routes, repo
  state, validators, and next validation commands for a goal
- **`agent-intents.txt`**: Intent map for common multi-repo agent tasks
- **`sync-report.sh`**: Detailed sync and dirty-work report for child repos
- **`check-repo-contract.sh`**: Contract check for one child repo
- **`validator-exceptions.sh`**: Report child repos still using non-native
  validation
- **`capabilities.sh`**: Tab-separated repo capability, route, and validator
  index
- **`ci-workflow-report.sh`**: Report child repo workflow presence
- **`generate-docs.sh`**: Regenerate `REPOSITORIES.md` from manifests
- **`native-workflow-template.sh`**: Check child CI workflows run native
  validators
- **`health-report.sh`**: Emit machine-readable repo health JSON
- **`route-quality.sh`**: Enforce required route capability keywords
- **`freshness-report.sh`**: Report last commit age for managed repos
- **`new-repo-check.sh`**: Validate the checklist for adding a managed repo
- **`add-repo.sh`**: Add a managed repo and validate the generated metadata
- **`change-report.sh`**: Summarize recent commits across checked-out repos
- **`tree-smoke-test.sh`**: Smoke-test the root scripts in a copied tree
- **`test-root-scripts.sh`**: Regression testing root setup/update behavior

The scripts read from a shared `repos.txt` file that defines all repositories.
Manifest parsing, category order, and validation live in
**`lib/repos.sh`**.
Repository state classification lives in **`lib/repo-state.sh`** so update and
validation commands share the same clean, dirty, missing, and detached checkout
rules.
Agent routing hints live in **`agent-routes.txt`** so agents can map goals to
owning repository paths without relying only on prose docs.
Use **`route.sh`** to query those routing hints.
Agent task intents live in **`agent-intents.txt`** so agents can map common
goals to primary and related repositories. Use **`agent-intake.sh`** first when
starting a goal because it joins intents, routes, state, validators, and next
commands into one task plan.
Declared child repository validators live in **`repo-validators.txt`**.
Use **`doctor.sh`** to summarize managed repo health, validator coverage, route
coverage, and origin sync state.

## repos.txt

The `repos.txt` file is the single source of truth for all repositories in the
set-me-up collection.
All `local_path` values in this manifest are reserved for cloned external
repositories (including `tests/`), not first-party tracked source in this
repository.

### Format

Each line follows the format: `repo_name|local_path|category`

- **repo_name**: GitHub repository name (without the org prefix)
- **local_path**: Relative path where the repo should be cloned
- **category**: Grouping category (`top-level`, `shared`, `module`, or `config`)

### Example

```text
# Repository definitions for set-me-up
# Format: repo_name|local_path|category

# Top-level repositories
set-me-up-blueprint|blueprint|top-level
set-me-up-tests|tests|top-level
utilities|utilities|top-level

# Module repositories
colorschemes|modules/colorschemes|module
set-me-up-debian-modules|modules/debian|module
set-me-up-macos-modules|modules/macos|module

# Config repositories
fish|home/.config/fish|config
zed|home/.config/zed|config
```

Lines starting with `#` are comments and empty lines are ignored.

`scripts/lib/repos.sh` validates this format for all root scripts. Update that
file when changing category order or manifest rules.

## agent-routes.txt

The `agent-routes.txt` file maps common goal areas to owning repository paths.
Each line follows the format:

```text
route_id|local_path|summary|keywords
```

- **route_id**: Stable kebab-case route name
- **local_path**: `.` or a path listed in `repos.txt`
- **summary**: Short ownership description
- **keywords**: Comma-separated routing hints

Root validation rejects route paths that are not listed in `repos.txt`.
Root tests also keep important route concepts covered, including `theme`,
`prompt`, `smu`, `claude`, `codex`, `macos`, `debian`, and `nvim`.

Query routes with:

```bash
scripts/route.sh theme
scripts/route.sh prompt
scripts/route.sh installer
```

## agent-intents.txt

The `agent-intents.txt` file maps common agent task types to the repositories
usually involved in the change. Each line follows the format:

```text
intent_id|primary_paths|related_paths|validation_commands|summary|keywords
```

- **intent_id**: Stable kebab-case task intent name
- **primary_paths**: Comma-separated primary repo paths
- **related_paths**: Comma-separated related repo paths
- **validation_commands**: Semicolon-separated root commands for this task
- **summary**: Short task description
- **keywords**: Comma-separated matching hints

Paths must be `.` or listed in `repos.txt`. Root validation rejects unknown
intent paths and keeps core intents present for common agent tasks.

## agent-intake.sh

The `agent-intake.sh` command is the preferred agent entry point for concrete
work. It checks `agent-intents.txt` first, then falls back to `agent-routes.txt`
when no intent matches.

```bash
scripts/agent-intake.sh theme
scripts/agent-intake.sh --explain theme
scripts/agent-intake.sh --plan theme
scripts/agent-intake.sh --strict theme
scripts/agent-intake.sh --json "change smu command"
```

Output includes:

- primary and related repository paths
- match confidence, numeric score, source, and explanation
- risk level and risk flags for blocking checkout or contract states
- matching route summaries
- current checkout state and origin sync state
- validator command for each repository
- local docs an agent should read before editing, with missing-doc warnings
- intent-specific next validation commands

Use `--json` for machine-readable task intake. Use `--plan` for an ordered
human-readable checklist. Use `--strict` when automation should fail on dirty,
detached, missing, not-git, behind, diverged, or missing-validator selected
repositories. Low-score matches are filtered unless they are the best available
match.

## doctor.sh

The `doctor.sh` command is read-only. It reports checkout state, route
coverage, validator coverage, and origin sync state across managed
repositories.

```bash
scripts/doctor.sh
scripts/doctor.sh --verbose
scripts/doctor.sh --json
```

Summary output includes:

- repository state counts (`clean`, `dirty`, `changed`, `detached`, and
  missing/not-git states)
- validator coverage
- route coverage and route drift
- sync state counts (`synced`, `ahead`, `behind`, `diverged`, and `unknown`)

Verbose output adds per-repository sync status such as `ahead:1`,
`behind:2`, or `diverged:21:7`.
JSON output is the preferred agent entry point for structured repository state.

## sync-report.sh

The `sync-report.sh` command is read-only. It prints one row per managed repo,
then expands dirty repositories with their `git status --short` details and
out-of-sync submodule pointers.

```bash
scripts/sync-report.sh
```

Use it before broad multi-repo work to understand which checkouts are safe to
edit and which need a human history decision.

## check-repo-contract.sh

The `check-repo-contract.sh` command validates one managed child repo against
the set-me-up contract:

- listed in `repos.txt`
- has a route in `agent-routes.txt`
- has a validator
- has a native executable `scripts/validate.sh`
- has README and license files
- is in an acceptable sync state

```bash
scripts/check-repo-contract.sh home/.config/zsh
scripts/check-repo-contract.sh --json home/.config/zsh
scripts/check-repo-contract.sh --allow-diverged home/.config/zsh
scripts/check-repo-contract.sh --all
scripts/check-repo-contract.sh --all --checked-out
```

The command exits non-zero when any contract item fails.

Use `--json` when an agent or script needs machine-readable check results.
Use `--allow-diverged` only for an intentionally parked diverged checkout.

## validator-exceptions.sh

The `validator-exceptions.sh` command lists managed child repositories that do
not currently expose an executable native validator at `scripts/validate.sh`.
Use it to prioritize the next native validator migration:

```bash
scripts/validator-exceptions.sh
scripts/validator-exceptions.sh --checked-out --strict
```

`--checked-out --strict` is used by root validation to enforce native
validators for local child checkouts while preserving root-only CI fallback
coverage.

## capabilities.sh

The `capabilities.sh` command joins `repos.txt`, `agent-routes.txt`, and
`repo-validators.txt` into one tab-separated index for agents and scripts:

```bash
scripts/capabilities.sh
scripts/capabilities.sh theme
```

## ci-workflow-report.sh

The `ci-workflow-report.sh` command reports whether checked-out child
repositories have GitHub Actions workflow files:

```bash
scripts/ci-workflow-report.sh --checked-out
```

Use `--strict` when missing workflow files should fail the command.

## native-workflow-template.sh

The `native-workflow-template.sh` command checks that checked-out child repos
with native validators also have a CI workflow that runs
`scripts/validate.sh --all`:

```bash
scripts/native-workflow-template.sh --check
```

## health-report.sh

The `health-report.sh` command emits machine-readable repository state for
agents:

```bash
scripts/health-report.sh --json
```

The JSON contract is documented in
`scripts/schemas/health-report.schema.json`, with a compact example in
`scripts/schemas/health-report.example.json`.

Additional JSON schemas live in `scripts/schemas/` for doctor, freshness,
change, capability, sync, update, CI workflow, and native workflow reports.
Use `scripts/validate-json-schemas.sh` to verify generated JSON report shape.

## add-repo.sh

The `add-repo.sh` command appends a managed repository to the root manifests,
regenerates `REPOSITORIES.md`, and runs the new-repo checklist plus structure
validation:

```bash
scripts/add-repo.sh repo-name local/path category route-id "Summary" \
  "keyword,aliases" "scripts/validate.sh --all"
```

## change-report.sh

The `change-report.sh` command summarizes recent commits across checked-out
managed repositories:

```bash
scripts/change-report.sh --since=14.days
scripts/change-report.sh --since=14.days --json
```

## tree-smoke-test.sh

The `tree-smoke-test.sh` command copies the root metadata/scripts into a
temporary tree and verifies that agent-facing discovery commands run without
hidden local state:

```bash
scripts/tree-smoke-test.sh
```

## route-quality.sh

The `route-quality.sh` command enforces route coverage for common capability
domains:

```bash
scripts/route-quality.sh
```

## freshness-report.sh

The `freshness-report.sh` command reports last commit age for managed repos:

```bash
scripts/freshness-report.sh
scripts/freshness-report.sh --json
SMU_STALE_DAYS=90 scripts/freshness-report.sh
```

## new-repo-check.sh

The `new-repo-check.sh` command validates the checklist for one managed repo:

```bash
scripts/new-repo-check.sh home/.config/zsh
```

## generate-docs.sh

The `generate-docs.sh` command regenerates `REPOSITORIES.md` from the root
manifests:

```bash
scripts/generate-docs.sh
```

## repo-validators.txt

The `repo-validators.txt` file declares validation commands for child
repositories. Each line follows the format:

```text
local_path|command
```

`validate-repos.sh` first uses a child repository's executable
`scripts/validate.sh`, then falls back to declared commands, `npm test`, or
`./test.sh`.

Prefer adding an executable `scripts/validate.sh` to the child repository so
validation lives with the repo that owns the behavior. Use
`repo-validators.txt` for transitional repositories, third-party repositories,
or local checkouts that cannot safely receive a native validator yet.

`scripts/validate.sh --coverage` fails when route coverage drifts or validator
coverage drops below every managed repository.

## Detailed Reference

See [SCRIPTS-DETAILS.md](docs/SCRIPTS-DETAILS.md) for setup, update,
repository lifecycle, troubleshooting, and maintenance details.
