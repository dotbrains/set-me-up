# Repository Index

Generated from scripts manifests. Do not edit by hand.

Regenerate with:

```bash
scripts/generate-docs.sh
```

## Capabilities

### set-me-up-blueprint

- URL: <https://github.com/smeltery/set-me-up-blueprint>
- Path: `blueprint`
- Category: `top-level`
- Route: `blueprint`
- Summary: Blueprint structure and bootstrap composition
- Keywords: `blueprint,bootstrap,composition,vps,server,headless,digitalocean,droplet,mode,modes,engine,provider,providers,provider-matrix,blueprint-recommend,recommend,recommendation,starter,write,validate-generated,capability,capabilities,github-actions,validate-contract,contract-validate,schema-backed,schema-backed-readiness,reusable-validator,json-schema,contract-schema,schema-command,schema-validation,contract-metadata,release-artifact,doctor,migrate,readiness,ci-contract,contract,portable,modular,architecture`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-docs

- URL: <https://github.com/smeltery/set-me-up-docs>
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

- URL: <https://github.com/smeltery/set-me-up-installer>
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

- URL: <https://github.com/smeltery/set-me-up-tests>
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

- URL: <https://github.com/smeltery/utilities>
- Path: `utilities`
- Category: `top-level`
- Route: `utilities`
- Summary: Shared utility shell functions
- Keywords: `utility,utilities,shell,function,helper`
- Validator:

  ```bash
  ./tests/main.sh && ./tests/integration_test.sh
  ```

### set-me-up-arch-modules

- URL: <https://github.com/smeltery/set-me-up-arch-modules>
- Path: `modules/arch`
- Category: `module`
- Route: `arch`
- Summary: Generic Arch Linux package installation (any Arch-based system)
- Keywords: `arch,arch-linux,linux,pacman,aur,yay`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-colorscheme-module

- URL: <https://github.com/smeltery/set-me-up-colorscheme-module>
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

- URL: <https://github.com/smeltery/set-me-up-debian-modules>
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

- URL: <https://github.com/smeltery/set-me-up-macos-modules>
- Path: `modules/macos`
- Category: `module`
- Route: `modules-macos`
- Summary: macOS and Homebrew modules
- Keywords: `macos,darwin,homebrew,brew,module`
- Validator:

  ```bash
  find . -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
  ```

### set-me-up-macports-module

- URL: <https://github.com/smeltery/set-me-up-macports-module>
- Path: `modules/macports`
- Category: `module`
- Route: `modules-macports`
- Summary: MacPorts module
- Keywords: `macports,ports,module`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-preferences-module

- URL: <https://github.com/smeltery/set-me-up-preferences-module>
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

### set-me-up-template-module

- URL: <https://github.com/smeltery/set-me-up-template-module>
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

- URL: <https://github.com/smeltery/set-me-up-universal-modules>
- Path: `modules/universal`
- Category: `module`
- Route: `modules-universal`
- Summary: Cross-platform modules
- Keywords: `universal,cross-platform,module`
- Validator:

  ```bash
  find . -type f -name '*.sh' -not -path '*/.git/*' -exec bash -n {} +
  ```

### set-me-up-omarchy-modules

- URL: <https://github.com/smeltery/set-me-up-omarchy-modules>
- Path: `modules/omarchy`
- Category: `module`
- Route: `omarchy`
- Summary: Omarchy (Arch + Hyprland) package installation and update hook
- Keywords: `omarchy,arch,hyprland,linux,pacman,aur,dhh`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```

### set-me-up-xcode-module

- URL: <https://github.com/smeltery/set-me-up-xcode-module>
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

- URL: <https://github.com/smeltery/shared-ai-config>
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

- URL: <https://github.com/smeltery/alacritty>
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

- URL: <https://github.com/smeltery/bash>
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

- URL: <https://github.com/smeltery/claude>
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

- URL: <https://github.com/smeltery/codex>
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

- URL: <https://github.com/smeltery/fish>
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

- URL: <https://github.com/smeltery/gh-dash>
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

- URL: <https://github.com/smeltery/nushell>
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

- URL: <https://github.com/smeltery/nvim>
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

- URL: <https://github.com/smeltery/opencode>
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

- URL: <https://github.com/smeltery/pi>
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

- URL: <https://github.com/smeltery/television>
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

- URL: <https://github.com/smeltery/tmux>
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

- URL: <https://github.com/smeltery/zed>
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

- URL: <https://github.com/smeltery/zsh>
- Path: `home/.config/zsh`
- Category: `config`
- Route: `zsh`
- Summary: Zsh shell configuration
- Keywords: `zsh,shell,prompt,ps1`
- Validator:

  ```bash
  scripts/validate.sh --all
  ```
