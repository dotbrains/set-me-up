# set-me-up 👷🏼

[![Lint](https://github.com/dotbrains/set-me-up/workflows/Lint/badge.svg)](https://github.com/dotbrains/set-me-up/actions/workflows/lint.yml)
[![Tests](https://github.com/dotbrains/set-me-up/workflows/Tests/badge.svg)](https://github.com/dotbrains/set-me-up/actions/workflows/tests.yml)
[![Release Readiness](https://github.com/dotbrains/set-me-up/actions/workflows/release-readiness.yml/badge.svg)](https://github.com/dotbrains/set-me-up/actions/workflows/release-readiness.yml)
[![License: PolyForm Shield 1.0.0](https://img.shields.io/badge/License-PolyForm%20Shield%201.0.0-blue.svg)](https://polyformproject.org/licenses/shield/1.0.0)

A comprehensive dotfiles and system configuration framework.

## Documentation

For detailed information about how set-me-up works, see the [documentation](https://github.com/dotbrains/set-me-up-docs).

For information about the setup and update scripts, see [scripts/SCRIPTS.md](scripts/SCRIPTS.md).
For the generated repository, route, capability, and validator index, see
[REPOSITORIES.md](REPOSITORIES.md).

For a headless Ubuntu/Debian VPS such as a DigitalOcean Droplet, use the
first-class VPS path documented in [scripts/VPS.md](scripts/VPS.md).

## Install/Update Readiness

The release-readiness workflow checks installer, blueprint, and scenario-test
compatibility on a schedule. It also gates provisioning preflight drift by
requiring the installer JSON contract example and blueprint GitHub Actions
preflight steps to stay in sync. It calls the installer-owned `smu contract
validate` rules for provisioning preflight, adapter capabilities, and blueprint
CI readiness so schema drift is checked through the same CLI contract users
consume. The readiness artifact includes each validated contract name, version,
validator command, schema file, and source payload path. It publishes a
`release-readiness.json` artifact, writes a run summary, opens or updates an
issue when readiness fails, and closes that issue when readiness is green again.
A separate install canary runs the public one-liner on a schedule.

Local maintainers can run:

```bash
scripts/release-install-update.sh --check --json
scripts/release-install-update.sh --candidate-check --json
scripts/release-install-update.sh --push --dry-run --tag vX.Y.Z --github-release
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and how to run
validation locally.

## Quick Setup

To clone all repositories and recreate the complete directory structure:

```bash
git clone https://github.com/dotbrains/set-me-up.git
cd set-me-up
chmod +x scripts/setup.sh
./scripts/setup.sh
```

## VPS Setup

Agents and maintainers can route VPS or DigitalOcean work through the
`vps-server-setup` intent:

```bash
scripts/agent-intake.sh --plan vps
```

The supported headless path installs a blueprint with platform-scoped
submodules, then runs `smu --setup-profile vps` instead of the
workstation-oriented Debian module set.

## Updating Repositories

To update all repositories to their latest versions:

```bash
cd set-me-up
./scripts/update.sh
```

The update script will automatically skip repositories with uncommitted
changes.

See [scripts/SCRIPTS.md](scripts/SCRIPTS.md) for detailed documentation on
both scripts.

## Directory Structure

```text
set-me-up/
├── blueprint/          # Blueprint configuration
├── docs/               # Documentation
├── installer/          # Installation scripts
├── tests/              # Docker-based provisioning test scenarios
├── utilities/          # Utility scripts
├── shared/
│   └── ai-config/      # Shared AI agent/skill definitions
├── modules/
│   ├── colorschemes/    # Color scheme configurations
│   ├── debian/         # Debian/Linux modules
│   ├── macos/          # macOS/Homebrew modules
│   ├── macports/       # MacPorts module
│   ├── preferences/    # Preferences module
│   ├── template-module/ # Template for new modules
│   ├── universal/      # Universal modules
│   └── xcode/          # Xcode module
└── home/
    ├── codex/          # Codex CLI configuration
    ├── claude/         # Claude Code configuration
    ├── pi/             # pi coding agent configuration
    └── .config/
        ├── alacritty/  # Alacritty terminal config
        ├── bash/       # Bash configuration
        ├── fish/       # Fish shell configuration
        ├── gh-dash/    # GitHub dashboard configuration
        ├── nushell/    # Nushell configuration
        ├── nvim/       # Neovim configuration
        ├── opencode/   # OpenCode configuration
        ├── television/ # Television (tv) configuration
        ├── tmux/       # Tmux configuration
        ├── zed/        # Zed configuration
        └── zsh/        # Zsh configuration
```

## Repositories

### Core

- [set-me-up-blueprint](https://github.com/dotbrains/set-me-up-blueprint)
- [set-me-up-docs](https://github.com/dotbrains/set-me-up-docs)
- [set-me-up-installer](https://github.com/dotbrains/set-me-up-installer)
- [utilities](https://github.com/dotbrains/utilities)

### Testing

- [set-me-up-tests](https://github.com/dotbrains/set-me-up-tests)

### Modules

- [colorscheme-module](https://github.com/dotbrains/colorscheme-module)
- [set-me-up-debian-modules](https://github.com/dotbrains/set-me-up-debian-modules)
- [set-me-up-macos-modules](https://github.com/dotbrains/set-me-up-macos-modules)
- [macports-module](https://github.com/dotbrains/macports-module)
- [preferences-module](https://github.com/dotbrains/preferences-module)
- [template-module](https://github.com/dotbrains/template-module)
- [set-me-up-universal-modules](https://github.com/dotbrains/set-me-up-universal-modules)
- [xcode-module](https://github.com/dotbrains/xcode-module)

### Shared

- [shared-ai-config](https://github.com/dotbrains/shared-ai-config)

### Config

- [alacritty](https://github.com/dotbrains/alacritty)
- [bash](https://github.com/dotbrains/bash)
- [claude](https://github.com/dotbrains/claude)
- [codex](https://github.com/dotbrains/codex)
- [fish](https://github.com/dotbrains/fish)
- [gh-dash](https://github.com/dotbrains/gh-dash)
- [nushell](https://github.com/dotbrains/nushell)
- [nvim](https://github.com/dotbrains/nvim)
- [opencode](https://github.com/dotbrains/opencode)
- [pi](https://github.com/dotbrains/pi)
- [television](https://github.com/dotbrains/television)
- [tmux](https://github.com/dotbrains/tmux)
- [zed](https://github.com/dotbrains/zed)
- [zsh](https://github.com/dotbrains/zsh)

## License

Licensed under [PolyForm Shield 1.0.0](https://polyformproject.org/licenses/shield/1.0.0).
See [LICENSE](LICENSE) for details.
