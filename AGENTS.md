# AGENTS.md

## Project Snapshot

`set-me-up` is the root coordinator and working hub for a collection of
dotbrains setup, dotfile, installer, module, test, utility, and
agent-configuration repositories. Its main job is to clone those repositories
into a predictable local directory layout so a user can start here, describe a
goal, and let an agent find the right repo or repos to change.

This root repository is intentionally small. Most directories that appear after
setup are separate Git repositories and are ignored by this repo. Work may still
belong in those child repositories; this file explains how to route it.

## Canonical Files

- `scripts/repos.txt`: Single source of truth for managed repositories,
  destination paths, and categories.
- `scripts/agent-routes.txt`: Machine-readable route map from goals and
  keywords to owning repository paths.
- `scripts/agent-intents.txt`: Machine-readable intent map from common agent
  tasks to primary and related repository paths.
- `scripts/agent-intake.sh`: Agent entrypoint that joins intents, routes,
  checkout state, validators, docs to read, and next validation commands.
- `scripts/route.sh`: Query helper for `scripts/agent-routes.txt`.
- `scripts/doctor.sh`: Read-only health report for managed repo state, route
  coverage, validator coverage, and origin sync state.
- `scripts/sync-report.sh`: Detailed sync and dirty-work report for managed
  repositories.
- `scripts/check-repo-contract.sh`: Contract check for one managed child repo.
- `scripts/validator-exceptions.sh`: Report child repos still using
  non-native validation.
- `scripts/capabilities.sh`: Tab-separated repository capability index for
  routing, keywords, and validators.
- `scripts/ci-workflow-report.sh`: Report checked-out child repos without
  GitHub Actions workflows.
- `scripts/generate-docs.sh`: Regenerates `REPOSITORIES.md` from manifests.
- `scripts/native-workflow-template.sh`: Checks child workflows run native
  repo validation.
- `scripts/health-report.sh`: Machine-readable JSON health report.
- `scripts/route-quality.sh`: Required route keyword quality gate.
- `scripts/freshness-report.sh`: Last-commit freshness report.
- `scripts/new-repo-check.sh`: Checklist validator for adding a managed repo.
- `scripts/add-repo.sh`: Validated workflow for adding a managed repo.
- `scripts/change-report.sh`: Recent cross-repo commit summary.
- `scripts/tree-smoke-test.sh`: Fresh-tree smoke test for root discovery tools.
- `scripts/docs/COMMANDS.md`: Generated command usage reference.
- `scripts/docs/AGENT-INTAKE.md`: Stable field and behavior contract for
  `scripts/agent-intake.sh`.
- `scripts/schemas/`: JSON schemas for machine-readable root reports.
- `scripts/validate-json-schemas.sh`: Validates generated JSON report shape.
- `REPOSITORIES.md`: Generated repository, route, capability, and validator
  index.
- `scripts/repo-validators.txt`: Machine-readable validation command map for
  child repositories.
- `scripts/lib/repos.sh`: Shared Repository Manifest module for category
  order, manifest validation, and repository iteration.
- `scripts/lib/manifest-index.sh`: Shared Manifest Index module for path,
  route, intent, and validator lookup helpers.
- `scripts/lib/repo-state.sh`: Shared Repository State module for missing,
  not-git, dirty, detached, changed, and clean checkout classification.
- `scripts/lib/repo-health.sh`: Shared Repository Health module for sync,
  validator, route, docs, and warning facts.
- `scripts/lib/check-runner.sh`: Shared Validation Runner module for timed
  checks, quiet output capture, verbose streaming, and summaries.
- `scripts/lib/agent-intake-render.sh`: Shared Agent Intake Renderer module
  for TSV, JSON, and plan output.
- `scripts/setup.sh`: Clones every repo listed in `scripts/repos.txt`.
- `scripts/update.sh`: Pulls every existing clean repo listed in
  `scripts/repos.txt`.
- `scripts/test-root-scripts.sh`: Regression tests for root setup/update
  behavior using mocked Git operations.
- `scripts/tests/test-lib-modules.sh`: Direct regression tests for shared root
  library modules.
- `scripts/validate-repos.sh`: Discovers child repo validators and runs them
  without touching dirty worktrees.
- `scripts/SCRIPTS.md`: User-facing behavior and maintenance docs for the
  setup/update scripts.
- `README.md`: High-level project overview and repository inventory.
- `CONTRIBUTING.md`: Local linting, testing, and contribution guidance.

## Agent Workflow

When the user asks for work on "set-me-up", start in this root repo and route
the goal before editing:

1. Run `scripts/route.sh <query>` or read `scripts/agent-routes.txt` to map
   goal keywords to likely owning repository paths.
2. Prefer `scripts/agent-intake.sh --json <query>` when starting a concrete
   task. It joins intent matches, route matches, checkout state, validators,
   docs to read, missing-doc warnings, match confidence, explanations, and next
   validation commands into one agent task plan.
   Use `scripts/agent-intake.sh --plan <query>` when you need a human-readable
   checklist and `scripts/agent-intake.sh --strict <query>` when blocking repo
   risks should fail fast.
3. Read `scripts/repos.txt` to confirm managed repositories and local paths.
4. Map the goal to the most likely repo or repos using the routing guide below.
5. Run `scripts/doctor.sh --summary` when you need a quick health overview.
   Use `scripts/doctor.sh --verbose` when ahead, behind, or diverged checkout
   state matters for the requested work.
   Use `scripts/sync-report.sh` when dirty files or nested submodule state
   matter.
6. Check whether those paths exist locally. If a required checkout is missing,
   run `./scripts/setup.sh` or clone only the needed repo, depending on scope.
7. Enter each target repo and read its local `AGENTS.md`, `CLAUDE.md`,
   `README.md`, or contribution docs before making changes there.
8. Make changes in the repo that owns the behavior. Cross-repo work is allowed
   when the user goal spans multiple managed repos.
9. Run validation from each changed repo, plus root validation when root files
   changed.
   Use `scripts/validate-repos.sh --changed` from the root when multiple child
   repos may need validation.
10. Report final status grouped by repository, including uncommitted changes and
   any checks that could not be run.

Do not assume the root repo owns a file just because it is visible under this
directory tree. Use Git boundaries and `scripts/repos.txt` to determine
ownership.

## Routing Guide

- Root setup orchestration: `scripts/setup.sh`, `scripts/update.sh`,
  `scripts/repos.txt`, root docs, and root CI live in this repo.
- Installer behavior and the `smu` command: `installer/`.
- End-to-end provisioning scenarios: `tests/`.
- Shared utility shell functions: `utilities/`.
- Blueprint structure and bootstrap composition: `blueprint/`.
- Published documentation site/content: `docs/`.
- AI agent shared configuration and skills: `shared/ai-config/`.
- Claude Code configuration: `home/claude/`.
- Codex configuration: `home/codex/`.
- Pi agent configuration: `home/pi/`.
- Shell configs: `home/.config/bash/`, `home/.config/fish/`,
  `home/.config/nushell/`, and `home/.config/zsh/`.
- Terminal/editor configs: `home/.config/alacritty/`,
  `home/.config/tmux/`, `home/.config/nvim/`, `home/.config/zed/`, and
  `home/.config/television/`.
- GitHub dashboard config: `home/.config/gh-dash/`.
- Platform modules: `modules/debian/`, `modules/macos/`,
  `modules/macports/`, and `modules/xcode/`.
- Cross-platform modules: `modules/universal/`.
- Color scheme behavior: `modules/colorschemes/`.
- Preferences behavior: `modules/preferences/`.
- New module patterns: `modules/template-module/`.

If a goal affects a config and its installer/module integration, change both
the config repo and the owning module or installer repo as needed.

## Repository Boundaries

Paths listed in `scripts/repos.txt` are external checkouts with their own Git
history:

- `blueprint/`, `docs/`, `installer/`, `tests/`, and `utilities/`
- `modules/*`
- `shared/ai-config/`
- `home/claude/`, `home/codex/`, `home/pi/`
- `home/.config/*`

It is valid to edit those paths when the routed goal belongs there. Keep each
repo's changes, validation, commits, and PRs separate unless the user
explicitly asks for a coordinated multi-repo commit strategy.
Some child repos contain their own nested checkouts or submodules; treat those
as separate Git boundaries too. Never stage parent-repo changes that only
represent nested checkout state unless the requested work is specifically to
update that nested reference.

## Where To Add Things

- Add or remove managed repos in `scripts/repos.txt`.
- Add or change goal-to-repo routing in `scripts/agent-routes.txt`.
- Change route lookup behavior in `scripts/route.sh`.
- Change repo health reporting in `scripts/doctor.sh`.
- Change detailed sync reporting in `scripts/sync-report.sh`.
- Change child repo contract checks in `scripts/check-repo-contract.sh`.
- Add or change child repo validation commands in `scripts/repo-validators.txt`.
  Prefer adding `scripts/validate.sh --all` inside the child repo first; use a
  root manifest command only when the child repo cannot safely own the
  validation contract yet.
- Change manifest parsing, category order, or manifest validation in
  `scripts/lib/repos.sh`.
- Change cross-manifest lookup helpers in `scripts/lib/manifest-index.sh`.
- Change repository cleanliness, detached-head, or origin-drift detection in
  `scripts/lib/repo-state.sh`.
- Change shared repo health facts in `scripts/lib/repo-health.sh`.
- Change timed validation execution behavior in `scripts/lib/check-runner.sh`.
- Change agent-intake output formatting in `scripts/lib/agent-intake-render.sh`.
- Document setup/update behavior in `scripts/SCRIPTS.md`.
- Document user-facing repo inventory or first-run commands in `README.md`.
- Document contributor workflow, linting, and tests in `CONTRIBUTING.md`.
- Change clone/update behavior in `scripts/setup.sh` and `scripts/update.sh`.
- Add CI changes under `.github/workflows/`.
- Add project-level agent guidance in this file. Keep tool-specific shims, such
  as `CLAUDE.md`, as pointers to this file when possible.
- Add product or behavior changes inside the child repo that owns that product
  or behavior.

When adding a new managed repo, update both `scripts/repos.txt` and any
user-facing inventory in `README.md` that should mention it.

## Manifest Rules

Each non-comment line in `scripts/repos.txt` uses:

```text
repo_name|local_path|category
```

Valid categories are:

- `top-level`
- `shared`
- `module`
- `config`

`local_path` values are reserved for cloned external repositories. Do not add
first-party root source files under a managed `local_path`.
All root scripts that read `scripts/repos.txt` must use `scripts/lib/repos.sh`
or lookup helpers from `scripts/lib/manifest-index.sh`; do not add another ad
hoc parser.

## Agent Route Map Rules

Each non-comment line in `scripts/agent-routes.txt` uses:

```text
route_id|local_path|summary|keywords
```

`local_path` must be `.` or a path listed in `scripts/repos.txt`. Keywords are
comma-separated lowercase routing hints for agents and humans.
Root tests expect route coverage for core concepts including `theme`, `prompt`,
`smu`, `claude`, `codex`, `macos`, `debian`, and `nvim`.

## Repository Validator Rules

Each non-comment line in `scripts/repo-validators.txt` uses:

```text
local_path|command
```

`local_path` must be a path listed in `scripts/repos.txt`. Commands run from
inside that child repository. `scripts/validate-repos.sh` prefers native child
repo validators before falling back to declared commands.

Prefer a native child repo contract:

```bash
scripts/validate.sh --all
```

Root `scripts/validate-repos.sh` infers this command automatically when it
exists and is executable, and it takes precedence over a root-declared command.
Declared root validators are for transitional cases, third-party constraints,
or repos whose local history cannot currently be changed safely. Run
`scripts/validator-exceptions.sh` to find the remaining repos that should move
toward native `scripts/validate.sh --all` contracts.

## Shell Script Style

- Use Bash for root scripts.
- Keep scripts executable.
- Preserve strict failure handling with `set -euo pipefail`.
- Prefer small focused functions for repeated behavior.
- Quote variables unless pattern matching or Bash syntax requires otherwise.
- Keep output style consistent with the existing categorized setup/update
  output.

## Validation

Run the narrowest relevant checks before finishing:

```bash
scripts/validate.sh --all
```

To enforce route and validator coverage without running every child repo test:

```bash
scripts/validate.sh --coverage
```

For routed multi-repo work, list or run child repo validators from the root:

```bash
scripts/validate-repos.sh --list
scripts/validate-repos.sh --changed
scripts/validate-repos.sh --missing
scripts/sync-report.sh
scripts/sync-report.sh --json
scripts/update.sh --plan --json
scripts/update.sh --apply --validate
scripts/validator-exceptions.sh
scripts/capabilities.sh --json theme
scripts/ci-workflow-report.sh --checked-out
scripts/native-workflow-template.sh --check
scripts/doctor.sh --json
scripts/health-report.sh --json
scripts/route-quality.sh
scripts/freshness-report.sh
scripts/freshness-report.sh --json
scripts/new-repo-check.sh home/.config/zsh
scripts/add-repo.sh repo path category route-id "Summary" "keywords"
scripts/change-report.sh --since=7.days --json
scripts/tree-smoke-test.sh
scripts/validate-json-schemas.sh
scripts/check-repo-contract.sh home/.config/zsh
scripts/check-repo-contract.sh --json home/.config/zsh
scripts/check-repo-contract.sh --all
```

`scripts/validate-repos.sh` skips dirty repositories so it cannot hide or
overwrite unrelated work-in-progress.

If `shellcheck` or `npx` is unavailable, report that instead of silently
skipping the check.

## Git Safety

- Expect child checkout directories to have their own Git state.
- Run `git status --short` in every repo before editing it.
- Never clean, reset, or overwrite child checkouts as part of root work.
- `scripts/update.sh` intentionally skips repos with uncommitted, staged, or
  untracked changes.
- Use conventional commits when committing root or child-repo changes.
