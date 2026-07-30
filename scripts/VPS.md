# VPS Setup

This is the first-class path for a headless Ubuntu or Debian VPS, including a
DigitalOcean Droplet.

## Route The Work

Agents should start with:

```bash
scripts/agent-intake.sh --plan vps
scripts/route.sh vps
```

The `vps-server-setup` intent points at:

- `tests/` for Docker scenario coverage.
- `modules/debian/` for server-safe Debian package modules.
- `blueprint/` for user-facing bootstrap and provisioning guidance.
- `installer/` when `smu` behavior itself must change.

## User Path

On a new Ubuntu/Debian VPS:

```bash
sudo apt-get update
sudo apt-get install -y bash curl git ca-certificates

INSTALL_URL="https://raw.githubusercontent.com/<YOUR-USERNAME>/<YOUR-BLUEPRINT-REPO>/<BRANCH>/dotfiles/modules/install.sh"
SMU_SUBMODULE_SCOPE=platform bash <(curl -s -L "$INSTALL_URL") --plan
SMU_SUBMODULE_SCOPE=platform bash <(curl -s -L "$INSTALL_URL")

smu --setup-profile vps
```

Use a forked/private blueprint for personal SSH, shell, and deployment
customizations. Keep host secrets out of the blueprint repository and inject
them through the VPS provider, a secrets manager, or one-off host setup.

## Nix On VPS Hosts

Debian, Ubuntu, and Arch VPS hosts can use the `home-manager` adapter when Nix
and Home Manager are installed on the host. This keeps the operating system
managed by the distro while allowing the user environment to come from Nix:

```toml
[provisioning]
adapter = "home-manager"

[profile.default]
modules = ["nushell", "neovim", "mise"]
```

Then apply the profile:

```bash
smu provisioning-adapter apply --adapter home-manager --profile default --action build
smu provisioning-adapter apply --adapter home-manager --profile default
```

Use the `nixos` adapter only on a real NixOS VPS image. On Debian, Ubuntu, and
Arch hosts, `smu provisioning-adapter doctor --json` reports `host_supported:
false` for `nixos` and apply refuses to run `nixos-rebuild`.

For a mixed migration, use `hybrid`:

```toml
[provisioning]
adapter = "hybrid"
nix_adapter = "home-manager"
```

Hybrid applies modules with Home Manager when a module publishes that adapter
and falls back to the existing `rcm` module path for legacy modules.

## Validation

For root metadata and agent routing:

```bash
scripts/agent-intake.sh --strict vps
scripts/validate.sh --coverage
```

For the end-to-end Linux path:

```bash
cd tests
./scripts/run-scenario.sh vps
```

The `vps` scenario provisions the `server/headless` Debian module in an Ubuntu
container so the DigitalOcean path stays covered without requiring a live
Droplet.

## Agent Examples

When the user says "set this up on a DigitalOcean Droplet", route with:

```bash
scripts/agent-intake.sh --strict vps
```

Then check these repos first:

- `installer/` for `smu --setup-profile vps` and platform submodule behavior.
- `blueprint/` for bootstrap guidance and submodule composition.
- `modules/debian/` for `server/headless` and optional server module slices.
- `tests/` for the `vps` scenario, smoke checks, and scenario metadata.

For a security-focused server follow-up, prefer a separate targeted module
such as `server/security` over expanding the headless baseline.
