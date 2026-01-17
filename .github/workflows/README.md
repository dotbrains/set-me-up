# GitHub Actions Workflows

This directory contains CI/CD workflows for the set-me-up repository.

## Workflows

### Lint (`lint.yml`)

Runs code quality and style checks on pull requests and pushes to main/master branches.

**Triggers:**
- Pull requests that modify `.md`, `.sh`, or `.bash` files
- Pushes to `main`/`master` branches with the same file changes

**Jobs:**
- **markdown-lint**: Validates Markdown formatting and style
- **link-checker**: Verifies all links in Markdown files are valid
- **shellcheck**: Static analysis for shell scripts
- **bash-syntax**: Validates bash syntax for all shell scripts

### Tests (`tests.yml`)

Runs comprehensive tests on both Ubuntu and macOS environments.

**Triggers:**
- All pushes
- All pull requests

**Jobs:**
- **test**: Runs on both `ubuntu-latest` and `macos-latest`
  - Tests bash syntax for `setup.sh`
  - Verifies git is installed
  - Tests idempotency logic (directory existence checks)
  - Validates file structure (README.md, setup.sh, .gitignore)
  - Verifies .gitignore entries
  - Validates README.md structure

## Running Locally

### Lint Checks

```bash
# Markdown lint (requires markdownlint-cli2)
markdownlint-cli2 "**/*.md"

# ShellCheck (requires shellcheck)
shellcheck setup.sh

# Bash syntax check
bash -n setup.sh
```

### Tests

```bash
# Test bash syntax
bash -n setup.sh

# Test git availability
command -v git

# Test idempotency
mkdir -p test_dir
cd test_dir
mkdir -p blueprint
# Run setup.sh and verify it skips existing directories
```

## Badge Status

Add these badges to your main README.md:

```markdown
![Lint](https://github.com/dotbrains/set-me-up/workflows/Lint/badge.svg)
![Tests](https://github.com/dotbrains/set-me-up/workflows/Tests/badge.svg)
```
