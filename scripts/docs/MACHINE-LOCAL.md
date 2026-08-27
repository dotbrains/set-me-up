# Machine-local configuration

Personal blueprints such as `nicholasadamou/dotfiles` can keep per-host files
outside commits and update checks.

## Installed blueprint (`~/set-me-up`)

Use the blueprint CLI or installer workflow:

```bash
dotfiles local init
dotfiles local doctor
# or: smu local init && smu local doctor --json
```

Documentation lives in the installer repo at
`installer/docs/machine-local.md` after `./scripts/setup.sh`.

Summary:

- Put host-specific dotfiles in `$SMU_HOME_DIR/dotfiles/local/` or
  `$SMU_HOME_DIR/dotfiles/tag-nicholas/local/private/`
- The `local` rcm tag is listed in `dotfiles/rcrc` for blueprint-root overlays
- Keep theme/prompt overrides in `~/.config/set-me-up/*.toml`
- Optional extra ignored paths in `~/.config/set-me-up/local.env`

Default ignored blueprint paths for Nick's dotfiles:

- `dotfiles/local/`
- `dotfiles/tag-local/`
- `dotfiles/tag-smu/`
- `dotfiles/tag-nicholas/local/private/`

`dotfiles update`, `smu update blueprint`, and the bootstrap installer skip
those paths when deciding whether the checkout is dirty.

## set-me-up development hub

This root repository coordinates shared smeltery repos. Do not store personal
machine settings in child checkouts you edit for day-to-day use. `./scripts/update.sh`
skips any managed repo with uncommitted changes.

For local development-only repos, keep a private manifest at
`scripts/local-repos.txt` (gitignored). Copy
`scripts/local-repos.txt.example` to get started. `./scripts/setup.sh` and
`./scripts/update.sh` read that file when present. Each line uses the same
format as `scripts/repos.txt`:

```text
my-private-tools|private/tools|top-level
```

Nothing in `scripts/local-repos.txt` is committed to set-me-up or checked by
root CI.

## Agent routing

Machine-local dotfile work belongs in the installed blueprint and installer,
not in this root repo, unless you are changing the ignore/update behavior
itself.

```bash
scripts/route.sh machine local config
scripts/agent-intake.sh --plan "machine local dotfiles"
```
