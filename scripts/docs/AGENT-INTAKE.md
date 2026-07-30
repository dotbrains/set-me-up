# Agent Intake Contract

`scripts/agent-intake.sh` is the stable task-intake surface for agents working
in the `set-me-up` root repository.

## Commands

```bash
scripts/agent-intake.sh <query>
scripts/agent-intake.sh --json <query>
scripts/agent-intake.sh --plan <query>
scripts/agent-intake.sh --explain <query>
scripts/agent-intake.sh --strict <query>
scripts/agent-intake-fixtures.sh --check
scripts/agent-intake-fixtures.sh --write
scripts/validate.sh --agent
```

Use `--json` for automation, `--plan` for a human-readable checklist, and
`--strict` when blocking checkout risks should fail the command.

## Stable JSON Fields

Top-level fields are stable:

- `query`
- `matchedIntents`
- `riskSummary`
- `ambiguities`
- `repositories`
- `nextCommands`

Repository fields are stable:

- `path`, `role`, `confidence`, `score`, `risk`, `source`, `explanation`
- `repo`, `route`, `summary`, `keywords`
- `state`, `sync`, `validator`
- `docs`, `warnings`, `risks`

Additive fields are allowed. Existing fields should not be renamed or removed
without updating `scripts/schemas/agent-intake.schema.json` and fixtures.

## Matching

Intent matching checks `scripts/agent-intents.txt` first. Route matching is a
fallback when no intent matches. Low-score matches are filtered unless they are
the best available match.

`ambiguities` reports multiple high-confidence intent matches so agents can
notice broad queries such as `theme` that span several workflows.

## Risks

`riskSummary.blocking` is `true` when selected repositories include blocking
risks. Blocking risks are:

- `dirty`
- `detached`
- `diverged`
- `behind`
- `missing`
- `not-git`
- `no-validator`

`missing-docs` is reported as a non-blocking medium risk.

## Fixtures

Fixture files under `scripts/tests/fixtures/agent-intake-*.json` store
normalized matching expectations for representative queries. Regenerate them
only when the intended matching contract changes:

```bash
scripts/agent-intake-fixtures.sh --write
scripts/agent-intake-fixtures.sh --check
```

`scripts/validate.sh --agent` runs the fast agent-operability contract: routes,
intents, intake JSON/plan output, fixtures, schema checks, and this document.
