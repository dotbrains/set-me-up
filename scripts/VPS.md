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
bash <(curl -s -L "$INSTALL_URL") --plan
bash <(curl -s -L "$INSTALL_URL")

smu --provision --modules server/headless --no-base
```

Use a forked/private blueprint for personal SSH, shell, and deployment
customizations. Keep host secrets out of the blueprint repository and inject
them through the VPS provider, a secrets manager, or one-off host setup.

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
