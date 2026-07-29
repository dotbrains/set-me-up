# Scripts Documentation

This document describes the setup and update scripts used to manage the
set-me-up repository collection.

## Overview

The set-me-up project consists of multiple repositories organized in a specific
directory structure. These scripts help manage these repositories:

- **`setup.sh`**: Initial cloning of all repositories
- **`update.sh`**: Updating existing repositories
- **`validate-repos.sh`**: Running validators across clean child repositories
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
Declared child repository validators live in **`repo-validators.txt`**.
Use **`doctor.sh`** to summarize managed repo health, validator coverage, and
route coverage.

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

Query routes with:

```bash
scripts/route.sh theme
scripts/route.sh prompt
scripts/route.sh installer
```

## doctor.sh

The `doctor.sh` command is read-only. It reports checkout state, route
coverage, and validator coverage across managed repositories.

```bash
scripts/doctor.sh
scripts/doctor.sh --verbose
```

## repo-validators.txt

The `repo-validators.txt` file declares validation commands for child
repositories. Each line follows the format:

```text
local_path|command
```

`validate-repos.sh` runs declared commands from inside the matching child
repository before using inferred fallbacks such as `scripts/validate.sh --all`,
`npm test`, or `./test.sh`.

## setup.sh

Initial setup script that clones all repositories defined in `repos.txt`.

### Usage

Remote execution (recommended for first-time setup):

```bash
curl -fsSL \
  https://raw.githubusercontent.com/dotbrains/set-me-up/master/\
scripts/setup.sh | bash
```

Local execution:

```bash
git clone https://github.com/dotbrains/set-me-up.git
cd set-me-up
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Features

- Clones repositories from the dotbrains GitHub organization
- Skips repositories that already exist
- Clones repositories with submodules (`--recursive`)
- Organizes repositories by category (top-level, shared, module, config)
- Creates necessary directory structure
- Clean, categorized output with emoji indicators

### Behavior

- If a repository directory already exists, it's skipped
- Creates `modules/`, `home/.config/`, and `shared/` directories
- Processes repositories in category order: top-level → shared → module → config

## update.sh

Update script that pulls the latest changes for all repositories.

### Update Usage

```bash
cd set-me-up
./scripts/update.sh
```

### Update Features

- Updates all repositories defined in `repos.txt`
- Skips repositories with uncommitted changes
- Uses `git pull --rebase --recurse-submodules`
- Updates submodules if present
- Clean, categorized output matching setup.sh style

### Safety Features

The script will skip a repository if:

- The directory doesn't exist
- The directory is not a git repository
- The repository has uncommitted changes (modified files)
- The repository has staged changes
- The repository has untracked files

This prevents accidental loss of work-in-progress changes.

### Output

```text
🔄 Updating set-me-up repositories...

📦 Updating top-level repositories...

  ⬆️  Updating blueprint...
       Already up to date.
  ✨ Done: blueprint

  ⏭️  docs has uncommitted changes, skipping...

🎉 Update complete! All repositories have been updated.
```

## Adding a New Repository

To add a new repository to the set-me-up collection:

1. Create the repository in the dotbrains GitHub organization
2. Add an entry to `repos.txt`:

   ```text
   new-repo-name|path/to/clone|category
   ```

3. Add or update the owning route in `agent-routes.txt`
4. Add a validation command to `repo-validators.txt` if the repo has one
5. Run `./scripts/setup.sh` to clone it (if setting up fresh) or
   manually clone it
6. Future runs of `./scripts/update.sh` will automatically include it

## Removing a Repository

To remove a repository from management:

1. Remove or comment out the line in `repos.txt`
2. Manually delete the local directory if desired

The scripts will no longer manage that repository.

## Troubleshooting

### "repos.txt not found" error

Ensure you're running the scripts from the set-me-up root directory where
`repos.txt` is located.

### Repository not updating

Check if the repository has uncommitted changes:

```bash
cd path/to/repo
git status
```

Commit or stash your changes, then run `./scripts/update.sh` again.

### Permission denied

Make sure the scripts are executable:

```bash
chmod +x scripts/setup.sh scripts/update.sh
```

## Maintenance

### Validation

Run the shared root validator before committing script changes:

```bash
scripts/validate.sh --all
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full linting guidelines.

Run child repository validators from the root when work spans multiple managed
repos:

```bash
scripts/validate-repos.sh --list
scripts/validate-repos.sh --changed
```

`validate-repos.sh` reads `repos.txt`, skips missing or dirty repositories, and
runs the first validator it can discover in this order:

1. `scripts/validate.sh --all`
2. `npm test`
3. `./test.sh`

### Testing Changes

When modifying the scripts:

1. Run `scripts/validate.sh --test`
2. Test in a temporary directory when changing real clone or pull behavior
3. Verify both fresh cloning and updates work
4. Test with repositories that have uncommitted changes
5. Verify the output formatting is clean and consistent
