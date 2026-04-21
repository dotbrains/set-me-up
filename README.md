# set-me-up 👷🏼

[![Lint](https://github.com/dotbrains/set-me-up/workflows/Lint/badge.svg)](https://github.com/dotbrains/set-me-up/actions/workflows/lint.yml)
[![Tests](https://github.com/dotbrains/set-me-up/workflows/Tests/badge.svg)](https://github.com/dotbrains/set-me-up/actions/workflows/tests.yml)
[![License: PolyForm Shield 1.0.0](https://img.shields.io/badge/License-PolyForm%20Shield%201.0.0-blue.svg)](https://polyformproject.org/licenses/shield/1.0.0/)

A comprehensive dotfiles and system configuration framework.

## Documentation

For detailed information about how set-me-up works, see the [documentation](https://github.com/dotbrains/set-me-up-docs).

For information about the setup and update scripts, see [scripts/SCRIPTS.md](scripts/SCRIPTS.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and how to run
lint checks locally.

## Quick Setup

To clone all repositories and recreate the complete directory structure:

```bash
git clone https://github.com/dotbrains/set-me-up.git
cd set-me-up
chmod +x scripts/setup.sh
./scripts/setup.sh
```

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

- [colorschemes](https://github.com/dotbrains/colorschemes)
- [debian-modules](https://github.com/dotbrains/set-me-up-debian-modules)
- [macos-modules](https://github.com/dotbrains/set-me-up-macos-modules)
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
- [zsh](https://github.com/dotbrains/zsh)

## License

Licensed under [PolyForm Shield 1.0.0](https://polyformproject.org/licenses/shield/1.0.0/).
See [LICENSE](LICENSE) for details.
