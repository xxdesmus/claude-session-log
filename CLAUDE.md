# claude-session-log — agent orientation

Claude Code plugin: two `PostToolUse` hooks that remind (never block) Claude
to keep a project's `SESSION_LOG.md` current. See `README.md` for full
rationale/trade-offs; this file is the fast map.

## File map

- `.claude-plugin/plugin.json` — plugin manifest, registers both hooks under
  `PostToolUse`, matchers `Bash` and `Write|Edit`.
- `.claude-plugin/marketplace.json` — personal marketplace listing (source
  `./`, so the plugin ships from this same repo).
- `hooks/session-log-commit-reminder.sh` — matcher `Bash`. Fires after any
  `git commit`/`git merge`; reminds if `SESSION_LOG.md` wasn't in the last
  commit's files.
- `hooks/session-log-spec-reminder.sh` — matcher `Write|Edit`. Fires after a
  write to `docs/superpowers/specs/*` or `docs/superpowers/plans/*`; reminds
  to log the new spec/plan.
- `docs/convention.md` — the actual `SESSION_LOG.md` convention (structure,
  update triggers). This is what a *consuming* project pastes/references
  into its own `CLAUDE.md` — the hooks are inert without it.

## How the hooks work (both scripts)

1. Read hook JSON from stdin (`input=$(cat)`).
2. Cheap bash substring pre-filter on the raw JSON before spawning `jq` —
   these run on every matching tool call, so the non-match case must be
   near-free.
3. `jq` extracts the real field (`.tool_input.command` or
   `.tool_input.file_path`/`.tool_response.filePath`) and re-checks precisely.
4. No match → `exit 0`, no output. Match → emit
   `{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"..."}}`.

Both are read-only and non-blocking by design — never `"decision":"block"`.
Depend on `jq` being installed; no fallback if it's missing (silent no-op).

## Editing/testing a hook

Pipe a fake hook payload on stdin and check stdout, e.g.:

```bash
echo '{"tool_input":{"command":"git commit -m x"}}' | ./hooks/session-log-commit-reminder.sh
```

No test suite — verify manually against the JSON shapes above before
changing matcher logic. Keep both scripts short (currently <15 lines) and
keep the cheap substring pre-filter as the first line of defense.
