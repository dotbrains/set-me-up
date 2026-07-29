# GitHub Actions Workflows

This directory contains CI/CD workflows for the set-me-up repository.

## Workflows

### Lint (`lint.yml`)

Runs code quality and style checks on pull requests and pushes to main/master
branches.

**Triggers:**

- Pull requests that modify `.md`, `.sh`, or `.bash` files
- Pushes to `main`/`master` branches with the same file changes

**Jobs:**

- **markdown-lint**: Validates Markdown formatting and style
- **shellcheck**: Static analysis for shell scripts
- **bash-syntax**: Validates bash syntax for all shell scripts

### Tests (`tests.yml`)

Runs comprehensive tests on both Ubuntu and macOS environments.

**Triggers:**

- All pushes
- All pull requests

**Jobs:**

- **test**: Runs on both `ubuntu-latest` and `macos-latest`
  - Tests bash syntax for root scripts
  - Runs the mocked root setup/update regression harness
  - Validates file structure and required manifest entries
  - Verifies .gitignore entries
  - Validates README.md structure
  - Enforces route and child-repo validator coverage

## Running Locally

### Lint Checks

```bash
# All checks
scripts/validate.sh --all

# Markdown lint
scripts/validate.sh --markdown

# ShellCheck
scripts/validate.sh --shell

# Bash syntax check only
scripts/validate.sh --bash
```

### Tests

```bash
# Test bash syntax
scripts/validate.sh --bash

# Test root setup and update behavior with mocked Git operations
scripts/validate.sh --test

# Enforce route and validator coverage
scripts/validate.sh --coverage

# Report child repo sync state
scripts/sync-report.sh

# Check one child repo contract
scripts/check-repo-contract.sh home/.config/zsh
scripts/check-repo-contract.sh --json home/.config/zsh
scripts/check-repo-contract.sh --all
scripts/validator-exceptions.sh
scripts/capabilities.sh theme
scripts/ci-workflow-report.sh --checked-out
```

The root script behavior is covered in CI with a mocked `git` command so tests
do not clone or pull remote repositories.

## Badge Status

Add these badges to your main README.md:

```markdown
![Lint](https://github.com/dotbrains/set-me-up/workflows/Lint/badge.svg)
![Tests](https://github.com/dotbrains/set-me-up/workflows/Tests/badge.svg)
```
