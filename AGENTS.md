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
- `scripts/repo-validators.txt`: Machine-readable validation command map for
  child repositories.
- `scripts/lib/repos.sh`: Shared Repository Manifest module for category
  order, manifest validation, and repository iteration.
- `scripts/lib/repo-state.sh`: Shared Repository State module for missing,
  not-git, dirty, detached, changed, and clean checkout classification.
- `scripts/setup.sh`: Clones every repo listed in `scripts/repos.txt`.
- `scripts/update.sh`: Pulls every existing clean repo listed in
  `scripts/repos.txt`.
- `scripts/test-root-scripts.sh`: Regression tests for root setup/update
  behavior using mocked Git operations.
- `scripts/validate-repos.sh`: Discovers child repo validators and runs them
  without touching dirty worktrees.
- `scripts/SCRIPTS.md`: User-facing behavior and maintenance docs for the
  setup/update scripts.
- `README.md`: High-level project overview and repository inventory.
- `CONTRIBUTING.md`: Local linting, testing, and contribution guidance.

## Agent Workflow

When the user asks for work on "set-me-up", start in this root repo and route
the goal before editing:

1. Read `scripts/agent-routes.txt` to map goal keywords to likely owning
   repository paths.
2. Read `scripts/repos.txt` to confirm managed repositories and local paths.
3. Map the goal to the most likely repo or repos using the routing guide below.
4. Check whether those paths exist locally. If a required checkout is missing,
   run `./scripts/setup.sh` or clone only the needed repo, depending on scope.
5. Enter each target repo and read its local `AGENTS.md`, `CLAUDE.md`,
   `README.md`, or contribution docs before making changes there.
6. Make changes in the repo that owns the behavior. Cross-repo work is allowed
   when the user goal spans multiple managed repos.
7. Run validation from each changed repo, plus root validation when root files
   changed.
   Use `scripts/validate-repos.sh --changed` from the root when multiple child
   repos may need validation.
8. Report final status grouped by repository, including uncommitted changes and
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
- Add or change child repo validation commands in `scripts/repo-validators.txt`.
- Change manifest parsing, category order, or manifest validation in
  `scripts/lib/repos.sh`.
- Change repository cleanliness, detached-head, or origin-drift detection in
  `scripts/lib/repo-state.sh`.
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
All root scripts that read `scripts/repos.txt` must use
`scripts/lib/repos.sh`; do not add another ad hoc parser.

## Agent Route Map Rules

Each non-comment line in `scripts/agent-routes.txt` uses:

```text
route_id|local_path|summary|keywords
```

`local_path` must be `.` or a path listed in `scripts/repos.txt`. Keywords are
comma-separated lowercase routing hints for agents and humans.

## Repository Validator Rules

Each non-comment line in `scripts/repo-validators.txt` uses:

```text
local_path|command
```

`local_path` must be a path listed in `scripts/repos.txt`. Commands run from
inside that child repository. `scripts/validate-repos.sh` prefers declared
commands before falling back to inferred validators.

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

For routed multi-repo work, list or run child repo validators from the root:

```bash
scripts/validate-repos.sh --list
scripts/validate-repos.sh --changed
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
