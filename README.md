# claude-session-log

Personal Claude Code plugin. Keeps a project's `SESSION_LOG.md` from going
stale during long or multi-agent sessions, per the "maintain a durable
handoff log" convention described in the global `CLAUDE.md`.

Two `PostToolUse` hooks:

- **`session-log-commit-reminder.sh`** (matcher: `Bash`) — after any `git
  commit`/`git merge`, checks whether `SESSION_LOG.md` was part of that
  commit. If not, injects a reminder to update it.
- **`session-log-spec-reminder.sh`** (matcher: `Write|Edit`) — after any
  write to `docs/superpowers/specs/*` or `docs/superpowers/plans/*`, injects
  a reminder to note the new spec/plan in `SESSION_LOG.md`.

Both hooks are advisory only (they emit `additionalContext`, never block).

## Install

```
/plugin marketplace add xxdesmus/claude-session-log
/plugin install claude-session-log@claude-session-log
```

Or add manually to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-session-log": {
      "source": { "source": "github", "repo": "xxdesmus/claude-session-log" }
    }
  },
  "enabledPlugins": {
    "claude-session-log@claude-session-log": true
  }
}
```
