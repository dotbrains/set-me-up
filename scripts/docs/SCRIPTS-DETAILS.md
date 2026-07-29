# Scripts Detailed Reference

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
scripts/capabilities.sh theme
scripts/ci-workflow-report.sh --checked-out
scripts/native-workflow-template.sh --check
scripts/health-report.sh --json
scripts/route-quality.sh
scripts/freshness-report.sh
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
