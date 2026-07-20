---
name: agentsbar
description: "AgentsBar read. Provider usage, limits, credits, config health. JSON. No writes."
---

# AgentsBar

Read AgentsBar. Never mutate config/auth.

## Run

```bash
skill="${CODEX_HOME:-$HOME/.codex}/skills/agentsbar"
"$skill/scripts/agentsbar" doctor
"$skill/scripts/agentsbar" providers
"$skill/scripts/agentsbar" usage
"$skill/scripts/agentsbar" usage --provider codex
"$skill/scripts/agentsbar" usage --all
```

All stdout: JSON. Upstream AgentsBar shape kept. Less drift, fewer tokens.

## Rules

- Start `doctor` when install/config unknown.
- `usage` reads enabled providers. Prefer this.
- `usage --provider ID` reads one provider.
- `usage --all` expensive; use only when needed.
- Identities hidden by default. `--include-identities` only when user explicitly needs them.
- Secrets always hidden.
- Helper read-only: fixed allowlist only. No config writes, auth repair, enable/disable, key storage.
- Timeout means upstream stuck. Narrow provider or raise `AGENTSBAR_TIMEOUT` (default 120 seconds).

## Binary

Auto-find: `AGENTSBAR_BIN`, PATH, app bundle, Homebrew cask. If missing: open AgentsBar, Preferences > Advanced > Install CLI; or set `AGENTSBAR_BIN`.

Each stdout/stderr stream capped at 1 MiB while fully drained. Timeout kills process group.
