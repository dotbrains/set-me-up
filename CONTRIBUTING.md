# Contributing

Thank you for contributing to set-me-up!

## Scripts Documentation

For detailed information about `setup.sh` and `update.sh`, see [scripts/SCRIPTS.md](scripts/SCRIPTS.md).

## Development Setup

### Prerequisites

Install the required linting tools:

```bash
# Install markdownlint-cli2 globally (optional)
npm install -g markdownlint-cli2

# Or use npx without installing (see commands below)

# Install shellcheck (macOS)
brew install shellcheck

# Install shellcheck (Ubuntu/Debian)
sudo apt-get install shellcheck
```

> **Note:** You can use `npx markdownlint-cli2` instead of installing
> globally. All markdown linting examples below show both options.

## Running Lint Checks Locally

Before pushing changes, run these checks locally to catch issues early:

### All Checks

Run all root checks at once:

```bash
scripts/validate.sh --all
```

### Individual Checks

#### Markdown Linting

```bash
scripts/validate.sh --markdown
```

Glob patterns starting with `#` exclude those directories from linting,
matching the entries in `.gitignore`.

Common markdown rules:

- **MD031**: Fenced code blocks need blank lines before and after
- **MD032**: Lists need blank lines before and after
- **MD040**: Code fences need language specified (e.g., \`\`\`bash)
- **MD013**: Lines should be under 80 characters

#### ShellCheck

```bash
scripts/validate.sh --shell
```

This performs static analysis on shell scripts to catch common issues.

#### Bash Syntax

```bash
scripts/validate.sh --bash
```

This checks for syntax errors without executing the script.

## Testing

### Run Tests Locally

```bash
scripts/validate.sh --test
scripts/validate.sh --structure
```

`--test` runs the root setup/update regression harness with mocked Git
operations, so it does not clone or pull remote repositories.

### File Structure Validation

Ensure these files exist:

- `README.md`
- `scripts/SCRIPTS.md`
- `scripts/agent-routes.txt`
- `scripts/repo-validators.txt`
- `scripts/lib/repos.sh`
- `scripts/lib/repo-state.sh`
- `scripts/lib/manifest-index.sh`
- `scripts/lib/repo-health.sh`
- `scripts/lib/check-runner.sh`
- `scripts/lib/agent-intake-match.sh`
- `scripts/lib/agent-intake-render.sh`
- `scripts/lib/release-readiness-render.sh`
- `scripts/route.sh` (must be executable)
- `scripts/doctor.sh` (must be executable)
- `scripts/setup.sh` (must be executable)
- `scripts/update.sh` (must be executable)
- `scripts/test-root-scripts.sh` (must be executable)
- `scripts/validate-repos.sh` (must be executable)
- `scripts/repos.txt`
- `.gitignore`

### .gitignore Validation

Verify the `.gitignore` contains:

- `blueprint/`
- `docs/`
- `home/`
- `installer/`
- `modules/`
- `utilities/`

## Child Repository Validation

Most directories created by `scripts/setup.sh` are separate Git repositories.
Validate routed multi-repo work from the root with:

```bash
scripts/validate-repos.sh --list
scripts/validate-repos.sh --changed
```

The runner reads `scripts/repos.txt`, discovers each child repo's validator,
and skips dirty repositories so unrelated work-in-progress stays untouched.

Use the read-only health report for a quick overview:

```bash
scripts/doctor.sh --summary
scripts/doctor.sh --verbose
```

When changing installer bootstrap or update behavior across `installer/`,
`blueprint/`, and `tests/`, follow the release order in
[scripts/docs/INSTALL-UPDATE-RELEASE.md](scripts/docs/INSTALL-UPDATE-RELEASE.md).

## Agent Route Map

When adding a repository or changing ownership language, update
`scripts/agent-routes.txt`. Root structure validation confirms every route path
is either `.` or a path from `scripts/repos.txt`.

## Repository Validators

When a child repository has a preferred validation command, declare it in
`scripts/repo-validators.txt`. Root structure validation confirms every
validator path is listed in `scripts/repos.txt`.

## Pre-commit Hook (Optional)

Create a pre-commit hook to automatically run checks:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "Running pre-commit checks..."

# Markdown lint
if ! scripts/validate.sh --all; then
    echo "❌ Validation failed"
    exit 1
fi

echo "✅ All checks passed!"
EOF

chmod +x .git/hooks/pre-commit
```

## Continuous Integration

All pull requests and pushes automatically run:

- **Lint workflow**: Markdown, ShellCheck, Bash syntax checks
- **Test workflow**: Tests on Ubuntu and macOS

View workflow status in the GitHub Actions tab on the repository.

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Run all lint checks locally
4. Commit your changes
5. Push to your fork
6. Open a pull request
7. Wait for CI checks to pass
8. Address any review feedback

## Questions?

Open an issue if you have questions or need help!
