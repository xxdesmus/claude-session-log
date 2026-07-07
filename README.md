# claude-session-log

A Claude Code plugin built to fix one specific, observed failure:
`SESSION_LOG.md` — a project's durable handoff file — goes stale mid-session,
because nothing actually enforces the "keep it updated" instruction once
real work starts.

## The problem

Claude Code sessions lose memory in three ways, none of which the model
controls:

- **Compaction.** Once the conversation nears the context limit, older turns
  get summarized. Detail survives only as much as the summary keeps it —
  usually "what changed," rarely "why," almost never "what's still broken."
- **API quota / rate limits.** A session can stop mid-task and resume later,
  possibly as a different model, with nothing but whatever compaction left
  behind.
- **Interruption.** The terminal closes, the user switches machines, or a
  different session picks up the same repo later.

`SESSION_LOG.md` — a plain file, committed to the repo, updated in place —
is the fix for all three: compaction can't touch it, quota exhaustion
doesn't erase it, and any model with zero prior context can `cat` it and
resume immediately.

But telling Claude "maintain this file" in `CLAUDE.md` doesn't hold up on
its own. That instruction is prose competing for attention with everything
else in context, and it loses predictably:

- **Long multi-step builds.** A nine-task feature built via subagents
  updates the log after task one, then attention moves to dispatching
  implementers, reviewing diffs, fixing bugs — and the log is still
  describing task one's state three hours and twenty commits later.
- **Session handoff.** Once context is summarized or a new session picks up
  the work, nothing re-raises "go write down what happened."
- **Subagents in worktrees.** A subagent implementing one task in an
  isolated worktree has no reason to know `SESSION_LOG.md` exists, let alone
  update it.

This isn't hypothetical — it's what prompted this repo. In the session that
built this plugin, a full feature (spec → plan → 9 implementation tasks →
review → merge) landed with `SESSION_LOG.md` stuck describing task one's
state the entire time. The user caught it by asking "is the session log up
to date?" The honest answer was no. Asking Claude to "just remember better"
doesn't fix this — the failure isn't a lapse in judgment on one turn, it's
that nothing in the environment ever re-raises the reminder at the moments
that matter.

## The fix: enforcement, not another instruction

This repo has two parts, and neither does much alone:

- **[`docs/convention.md`](docs/convention.md)** — the actual
  `SESSION_LOG.md` convention: why it exists, what triggers an update, the
  required file structure. Put this (or a reference to it) in `CLAUDE.md` —
  it's the part a model actually reads to know what a correct log entry
  looks like.
- **Two `PostToolUse` hooks** — enforcement. They don't write the file or
  define its shape; they watch for the two moments an update is most likely
  to be forgotten, and say so when it was:
  - **`session-log-commit-reminder.sh`** (matcher: `Bash`) — after any `git
    commit`/`git merge`, checks whether `SESSION_LOG.md` was part of that
    commit via `git show -1 --name-only HEAD`. If not, injects a
    reminder as `hookSpecificOutput.additionalContext`.
  - **`session-log-spec-reminder.sh`** (matcher: `Write|Edit`) — after any
    write to `docs/superpowers/specs/*` or `docs/superpowers/plans/*`
    (i.e. a new body of work starting), injects a reminder to note it.

Both are read-only and non-blocking — they inspect state and emit context,
never `"decision": "block"`. No match, no output, no cost. Both also
pre-filter on the raw tool-call JSON with a plain bash substring test before
ever spawning `jq` — since these hooks fire on *every* matching tool call,
the common case (a Bash call that isn't a commit, a Write that isn't a spec)
should cost nothing but a string comparison.

The mechanism is structural, not behavioral: hooks fire on tool-call
*events*, deterministically, regardless of what Claude is currently focused
on. There's no way for "got busy with task 4" to suppress an event a hook is
watching for — which is exactly the gap that let the real incident above
happen.

## Data flow

```
  Claude runs a tool (git commit, or Write/Edit)
                    │
                    ▼
        PostToolUse hook fires
                    │
                    ▼
    trigger moment? (commit missing the
    log, or a new spec/plan written)
         │                  │
         no                yes
         │                  │
         ▼                  ▼
      silent          additionalContext reminder
      (exit 0)        injected into Claude's context
                                │
                                ▼
                    Claude updates SESSION_LOG.md
```

Two scripts, same shape: `session-log-commit-reminder.sh` watches `Bash`
calls for `git commit`/`git merge`; `session-log-spec-reminder.sh` watches
`Write`/`Edit` calls for `docs/superpowers/{specs,plans}/`. Full per-check
logic is in the scripts themselves — both under 15 lines.

## Why this is the right shape for the problem

- **Vs. the instruction alone:** an instruction in `CLAUDE.md` is advice a
  model tries to remember. A hook is code that runs. This moves the
  reminder out of "things the model has to keep proactively re-noticing"
  and into "things the harness enforces on every matching event."
- **Vs. a `Stop` hook checked every turn:** far noisier — it would fire
  after every response, most of which touch neither git nor specs,
  drowning the signal. Scoping to `Bash`/`Write|Edit` with a content check
  means the reminder only appears at the two moments it's actually
  relevant.
- **Vs. an `agent`-type hook that rewrites the log automatically:**
  tempting, but the wrong trust boundary — an LLM call writing to a durable
  project file on every commit is slower, spends tokens whether or not an
  update is even needed, and risks silently overwriting good log content
  with a worse auto-summary. A plain reminder keeps a human (or the primary
  agent, deliberately) in control of what actually gets written.
- **Vs. copy-pasting the two scripts into each project's
  `.claude/settings.json`:** works once, then drifts — a fix to one copy
  never reaches the others. A plugin with its own repo means every
  machine/project that installs it gets the same version, and improvements
  propagate by bumping the marketplace.
- **Vs. publishing to the official plugin marketplace:** this encodes one
  person's specific `SESSION_LOG.md` convention, not a general-purpose
  tool — listing it publicly would present a personal workflow preference
  as broadly-endorsed practice. A public-but-unlisted repo gets the
  reuse-across-machines benefit without that.

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

Then wire in the convention itself — the hooks are inert without it. Add to
`CLAUDE.md` (global `~/.claude/CLAUDE.md` for every project, or a specific
project's):

```
Maintain SESSION_LOG.md per docs/convention.md in the claude-session-log
plugin (github.com/xxdesmus/claude-session-log).
```

or paste `docs/convention.md`'s content in directly for something
self-contained, with no cross-repo reference.
