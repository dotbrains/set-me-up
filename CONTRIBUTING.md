# Contributing

Thank you for contributing to set-me-up!

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

### All Lint Checks

Run all linting checks at once:

```bash
# Markdown linting (installed globally)
markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
  "#installer" "#modules" "#utilities"

# Or with npx (no installation needed)
npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
  "#installer" "#modules" "#utilities"

# ShellCheck
shellcheck setup.sh

# Bash syntax check
bash -n setup.sh
```

### Individual Checks

#### Markdown Linting

```bash
# With global installation
markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
  "#installer" "#modules" "#utilities"

# Or with npx (no installation needed)
npx markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
  "#installer" "#modules" "#utilities"
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
shellcheck setup.sh
```

This performs static analysis on shell scripts to catch common issues.

#### Bash Syntax

```bash
bash -n setup.sh
```

This checks for syntax errors without executing the script.

## Testing

### Run Tests Locally

```bash
# Test bash syntax
bash -n setup.sh

# Test git check
command -v git &> /dev/null && echo "✓ Git installed" || echo "✗ Git missing"

# Test idempotency (create test directory)
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p blueprint
# Copy and run setup.sh to verify it skips existing directories
```

### File Structure Validation

Ensure these files exist:

- `README.md`
- `setup.sh` (must be executable)
- `.gitignore`

### .gitignore Validation

Verify the `.gitignore` contains:

- `blueprint/`
- `docs/`
- `home/`
- `installer/`
- `modules/`
- `utilities/`

## Pre-commit Hook (Optional)

Create a pre-commit hook to automatically run checks:

```bash
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

echo "Running pre-commit checks..."

# Markdown lint
if ! markdownlint-cli2 "**/*.md" "#blueprint" "#docs" "#home" \
    "#installer" "#modules" "#utilities"; then
    echo "❌ Markdown linting failed"
    exit 1
fi

# ShellCheck
if ! shellcheck setup.sh; then
    echo "❌ ShellCheck failed"
    exit 1
fi

# Bash syntax
if ! bash -n setup.sh; then
    echo "❌ Bash syntax check failed"
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

View workflow status at:

- [Lint Workflow](https://github.com/dotbrains/set-me-up/actions/workflows/lint.yml)
- [Test Workflow](https://github.com/dotbrains/set-me-up/actions/workflows/tests.yml)

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
