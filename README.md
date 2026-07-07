# claude-session-log

Personal Claude Code plugin. Keeps a project's `SESSION_LOG.md` from going
stale during long or multi-agent sessions, per the "maintain a durable
handoff log" convention described in the global `CLAUDE.md`.

## The problem this solves

`CLAUDE.md` can tell Claude "keep `SESSION_LOG.md` current" all it wants, but
that instruction is just prose sitting in context. It competes with
everything else Claude is holding in its head, and it silently loses:

- **Long multi-step builds.** A nine-task feature built via subagents will
  update `SESSION_LOG.md` after task one, then the controller's attention
  moves to dispatching implementers, reviewing diffs, and fixing bugs —
  and the log is still describing task one's state three hours and twenty
  commits later.
- **Compaction and session handoff.** Once context is summarized or a new
  session picks up the work, there's no forcing function left telling
  Claude "by the way, go write down what happened."
- **Subagents in worktrees.** A subagent implementing a task in an isolated
  worktree has no reason to know `SESSION_LOG.md` exists at all, let alone
  update it.

This isn't hypothetical — it's what actually happened in the session this
plugin was built in: a full feature (spec → plan → 9 implementation tasks →
review → merge) landed with `SESSION_LOG.md` stuck describing task one's
state the entire time. The user caught it by asking "is the session log up
to date?" The honest answer was no.

Asking Claude to "just remember to update the log more often" doesn't fix
this, because the failure isn't a lapse in judgment on any single turn —
it's that nothing in the environment ever re-raises the reminder at the
moments that matter.

## How it works

Two `PostToolUse` hooks — small, boring shell scripts, not another LLM call:

- **`session-log-commit-reminder.sh`** (matcher: `Bash`) — runs after every
  Bash tool call. It only acts if the command text matches `git commit` or
  `git merge`. If it does, it runs `git show --stat -1 --name-only HEAD` and
  checks whether `SESSION_LOG.md` is in that commit's file list. If the log
  wasn't touched, it returns a `hookSpecificOutput.additionalContext` message
  that gets injected straight back into Claude's context: a reminder, not a
  block.
- **`session-log-spec-reminder.sh`** (matcher: `Write|Edit`) — runs after
  every file write/edit. It only acts if the path is under
  `docs/superpowers/specs/` or `docs/superpowers/plans/` — i.e. the moment a
  new design or implementation plan is committed to disk, which is exactly
  when a fresh body of work is starting and is worth a durable note.

Both hooks are read-only and non-blocking: they inspect state and emit
context, they never set `"decision": "block"`. If a commit already touched
the log, or the write isn't a spec/plan, the hook exits 0 with no output and
costs nothing.

The mechanism that makes this work is structural, not behavioral: hooks fire
on tool-call *events*, deterministically, regardless of what Claude is
currently thinking about. There's no way for "got busy with task 4" to
suppress an event a hook is watching for.

## Why this over the alternatives

- **Vs. relying on the instruction alone (status quo):** an instruction in
  `CLAUDE.md` is advice Claude tries to remember. A hook is code that runs.
  The whole point is moving the reminder out of "things the model has to
  keep proactively re-noticing" and into "things the harness enforces on
  every matching event," which is exactly the gap that caused the real
  incident above.
- **Vs. a `Stop` hook that checks at the end of every turn:** far noisier —
  it would fire after every single response, most of which don't touch git
  or specs at all, drowning the signal. Scoping to `Bash`/`Write|Edit` with a
  content check means the reminder only appears at the two moments it's
  actually relevant.
- **Vs. an `agent`-type hook that re-writes the log automatically:** tempting,
  but wrong trust boundary — an LLM call writing to a durable project file
  on every commit is slower, costs tokens on every single commit whether or
  not one is needed, and risks silently overwriting log content with a worse
  summary than a human-directed update would produce. A plain reminder keeps
  a human (or the primary agent, deliberately) in control of what actually
  gets written.
- **Vs. copy-pasting the two shell scripts into every project's
  `.claude/settings.json`:** works, but drifts — a fix or improvement to one
  copy doesn't reach the others. Packaging as a plugin with its own repo
  means every machine/project that installs it gets the same version, and
  updates propagate by just bumping the marketplace.
- **Vs. a full marketplace submission to the official plugin registry:**
  this is a narrow, personal convention (tied to this user's specific
  `CLAUDE.md` session-log rule), not a general-purpose tool — publishing it
  publicly as a listed plugin would be presenting a personal workflow
  preference as broadly-endorsed practice. A public-but-unlisted repo gets
  the reuse-across-machines benefit without that.

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
