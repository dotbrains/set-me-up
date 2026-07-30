# Repository Index

Generated from scripts manifests. Do not edit by hand.

Regenerate with:

```bash
scripts/generate-docs.sh
```

## Capabilities

### set-me-up-blueprint

- URL: <https://github.com/dotbrains/set-me-up-blueprint>
- Path: `blueprint`
- Category: `top-level`
- Route: `blueprint`
- Summary: Blueprint structure and bootstrap composition
- Keywords: `blueprint,bootstrap,composition,vps,server,headless,digitalocean,droplet,mode,modes,engine,provider,providers,github-actions`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-docs

- URL: <https://github.com/dotbrains/set-me-up-docs>
- Path: `docs`
- Category: `top-level`
- Route: `docs`
- Summary: Published documentation site and content
- Keywords: `docs,documentation,site,guide`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-installer

- URL: <https://github.com/dotbrains/set-me-up-installer>
- Path: `installer`
- Category: `top-level`
- Route: `installer`
- Summary: Installer behavior and smu command implementation
- Keywords: `installer,smu,cli,theme,prompt,catalog,profile,vps,server,headless,digitalocean,droplet`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-tests

- URL: <https://github.com/dotbrains/set-me-up-tests>
- Path: `tests`
- Category: `top-level`
- Route: `tests`
- Summary: End-to-end provisioning scenarios
- Keywords: `test,tests,e2e,scenario,provisioning,docker,vps,server,headless,digitalocean,droplet`
- Validator:

  ```bash
  shellcheck scripts/run-scenario.sh scripts/in-container-run.sh \
  scripts/lib/assertions.sh
  ```

### utilities

- URL: <https://github.com/dotbrains/utilities>
- Path: `utilities`
- Category: `top-level`
- Route: `utilities`
- Summary: Shared utility shell functions
- Keywords: `utility,utilities,shell,function,helper`
- Validator:

  ```bash
  ./tests/main.sh && ./tests/integration_test.sh
  ```

### colorscheme-module

- URL: <https://github.com/dotbrains/colorscheme-module>
- Path: `modules/colorschemes`
- Category: `module`
- Route: `modules-colorschemes`
- Summary: Color scheme behavior and adapters
- Keywords: `theme,themes,color,colorscheme,colorschemes`
- Validator:

  ```bash
  ./tests/main.sh && python3 scripts/theme_contract.py --local && \
  python3 scripts/generate-theme-adapters.py --check
  ```

### set-me-up-debian-modules

- URL: <https://github.com/dotbrains/set-me-up-debian-modules>
- Path: `modules/debian`
- Category: `module`
- Route: `modules-debian`
- Summary: Debian and Linux modules
- Keywords: `debian,linux,apt,module,vps,server,headless,digitalocean,droplet,ubuntu`
- Validator:

  ```bash
  find . -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
  ```

### set-me-up-macos-modules

- URL: <https://github.com/dotbrains/set-me-up-macos-modules>
- Path: `modules/macos`
- Category: `module`
- Route: `modules-macos`
- Summary: macOS and Homebrew modules
- Keywords: `macos,darwin,homebrew,brew,module`
- Validator:

  ```bash
  find . -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
  ```

### macports-module

- URL: <https://github.com/dotbrains/macports-module>
- Path: `modules/macports`
- Category: `module`
- Route: `modules-macports`
- Summary: MacPorts module
- Keywords: `macports,ports,module`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### preferences-module

- URL: <https://github.com/dotbrains/preferences-module>
- Path: `modules/preferences`
- Category: `module`
- Route: `modules-preferences`
- Summary: Preferences module
- Keywords: `preferences,defaults,settings,module`
- Validator:

  ```bash
  ./tests/main.sh && find macos arch debian universal -type f -name \
  '*.sh' -exec bash -n {} +
  ```

### template-module

- URL: <https://github.com/dotbrains/template-module>
- Path: `modules/template-module`
- Category: `module`
- Route: `modules-template`
- Summary: Template for new modules
- Keywords: `template,module,new-module,scaffold`
- Validator:

  ```bash
  find . -type f \( -name '*.sh' -o -name '*.bash' \) -not -path \
  '*/.*' -exec bash -n {} +
  ```

### set-me-up-universal-modules

- URL: <https://github.com/dotbrains/set-me-up-universal-modules>
- Path: `modules/universal`
- Category: `module`
- Route: `modules-universal`
- Summary: Cross-platform modules
- Keywords: `universal,cross-platform,module`
- Validator:

  ```bash
  find . -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
  ```

### xcode-module

- URL: <https://github.com/dotbrains/xcode-module>
- Path: `modules/xcode`
- Category: `module`
- Route: `modules-xcode`
- Summary: Xcode module
- Keywords: `xcode,developer-tools,module`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### shared-ai-config

- URL: <https://github.com/dotbrains/shared-ai-config>
- Path: `shared/ai-config`
- Category: `shared`
- Route: `ai-config`
- Summary: Shared AI agent configuration and skills
- Keywords: `agent,ai,skill,skills,shared-config`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### alacritty

- URL: <https://github.com/dotbrains/alacritty>
- Path: `home/.config/alacritty`
- Category: `config`
- Route: `alacritty`
- Summary: Alacritty terminal configuration
- Keywords: `alacritty,terminal,theme`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### bash

- URL: <https://github.com/dotbrains/bash>
- Path: `home/.config/bash`
- Category: `config`
- Route: `bash`
- Summary: Bash shell configuration
- Keywords: `bash,shell,prompt,ps1`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### claude

- URL: <https://github.com/dotbrains/claude>
- Path: `home/claude`
- Category: `config`
- Route: `claude`
- Summary: Claude Code configuration
- Keywords: `claude,claude-code,agent-config`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### codex

- URL: <https://github.com/dotbrains/codex>
- Path: `home/codex`
- Category: `config`
- Route: `codex`
- Summary: Codex configuration
- Keywords: `codex,agent-config`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### fish

- URL: <https://github.com/dotbrains/fish>
- Path: `home/.config/fish`
- Category: `config`
- Route: `fish`
- Summary: Fish shell configuration
- Keywords: `fish,shell,prompt`
- Validator:

  ```bash
  find . -type f -name '*.fish' -not -path '*/.git/*' -exec fish \
  --no-execute {} +
  ```

### gh-dash

- URL: <https://github.com/dotbrains/gh-dash>
- Path: `home/.config/gh-dash`
- Category: `config`
- Route: `gh-dash`
- Summary: GitHub dashboard configuration
- Keywords: `gh-dash,github,dashboard`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### nushell

- URL: <https://github.com/dotbrains/nushell>
- Path: `home/.config/nushell`
- Category: `config`
- Route: `nushell`
- Summary: Nushell configuration
- Keywords: `nushell,nu,shell,prompt`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### nvim

- URL: <https://github.com/dotbrains/nvim>
- Path: `home/.config/nvim`
- Category: `config`
- Route: `nvim`
- Summary: Neovim configuration
- Keywords: `nvim,neovim,editor,theme`
- Validator:

  ```bash
  make test
  ```

### opencode

- URL: <https://github.com/dotbrains/opencode>
- Path: `home/.config/opencode`
- Category: `config`
- Route: `opencode`
- Summary: OpenCode configuration
- Keywords: `opencode,agent-config`
- Validator:

  ```bash
  jq empty opencode.json opencode-swarm.json tui.json
  ```

### pi

- URL: <https://github.com/dotbrains/pi>
- Path: `home/pi`
- Category: `config`
- Route: `pi`
- Summary: Pi coding agent configuration
- Keywords: `pi,agent-config`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### television

- URL: <https://github.com/dotbrains/television>
- Path: `home/.config/television`
- Category: `config`
- Route: `television`
- Summary: Television picker configuration
- Keywords: `television,tv,picker`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### tmux

- URL: <https://github.com/dotbrains/tmux>
- Path: `home/.config/tmux`
- Category: `config`
- Route: `tmux`
- Summary: Tmux terminal multiplexer configuration
- Keywords: `tmux,terminal,theme`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### zed

- URL: <https://github.com/dotbrains/zed>
- Path: `home/.config/zed`
- Category: `config`
- Route: `zed`
- Summary: Zed editor configuration
- Keywords: `zed,editor,theme`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### zsh

- URL: <https://github.com/dotbrains/zsh>
- Path: `home/.config/zsh`
- Category: `config`
- Route: `zsh`
- Summary: Zsh shell configuration
- Keywords: `zsh,shell,prompt,ps1`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```
