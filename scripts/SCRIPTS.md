# Scripts Documentation

This document describes the setup and update scripts used to manage the
set-me-up repository collection.

## Overview

The set-me-up project consists of multiple repositories organized in a specific
directory structure. Two scripts help manage these repositories:

- **`setup.sh`**: Initial cloning of all repositories
- **`update.sh`**: Updating existing repositories

Both scripts read from a shared `repos.txt` file that defines all repositories.

## repos.txt

The `repos.txt` file is the single source of truth for all repositories in the
set-me-up collection.

### Format

Each line follows the format: `repo_name|local_path|category`

- **repo_name**: GitHub repository name (without the org prefix)
- **local_path**: Relative path where the repo should be cloned
- **category**: Grouping category (`top-level`, `module`, or `config`)

### Example

```text
# Repository definitions for set-me-up
# Format: repo_name|local_path|category

# Top-level repositories
set-me-up-blueprint|blueprint|top-level
utilities|utilities|top-level

# Module repositories
colorschemes|modules/colorschemes|module

# Config repositories
fish|home/.config/fish|config
```

Lines starting with `#` are comments and empty lines are ignored.

## setup.sh

Initial setup script that clones all repositories defined in `repos.txt`.

### Usage

Remote execution (recommended for first-time setup):

```bash
curl -fsSL \
  https://raw.githubusercontent.com/dotbrains/set-me-up/master/scripts/setup.sh | \
  bash
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
- Organizes repositories by category (top-level, module, config)
- Creates necessary directory structure
- Clean, categorized output with emoji indicators

### Behavior

- If a repository directory already exists, it's skipped
- Creates `modules/` and `home/.config/` directories
- Processes repositories in category order: top-level → module → config

## update.sh

Update script that pulls the latest changes for all repositories.

### Usage

```bash
cd set-me-up
./scripts/update.sh
```

### Features

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

3. Run `./scripts/setup.sh` to clone it (if setting up fresh) or manually clone it
4. Future runs of `./scripts/update.sh` will automatically include it

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

### Lint Checks

Both scripts should pass shellcheck:

```bash
shellcheck scripts/setup.sh scripts/update.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for full linting guidelines.

### Testing Changes

When modifying the scripts:

1. Test in a temporary directory
2. Verify both fresh cloning and updates work
3. Test with repositories that have uncommitted changes
4. Verify the output formatting is clean and consistent
