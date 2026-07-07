# The `SESSION_LOG.md` convention

This is the actual rule the two hooks enforce. The hooks only nudge — they
don't create the file, don't define its shape, and don't write to it. That's
still on Claude, driven by this convention. Copy this into a project's
`CLAUDE.md` (or your global `~/.claude/CLAUDE.md`) for it to have any effect.

## Why this file exists

Claude Code has three ways a session's memory disappears out from under it,
none of which the model controls:

- **Compaction.** Once the conversation approaches the context limit, older
  turns get summarized. Detail survives only as much as the summary
  preserves it — which is usually "what," rarely "why," and almost never
  "what's still broken."
- **API quota / rate limits.** A session can simply stop mid-task and pick
  back up later, possibly as a different model entirely, with nothing but
  whatever summary compaction left behind.
- **Interruption.** The user closes the terminal, switches machines, or a
  different session picks up the same repo later.

A model can't `git log` its way back to *intent* — commit messages say what
changed, not what's half-done, what's blocked, or what was tried and
abandoned. `SESSION_LOG.md` is a plain file in the repo, so it survives all
three: compaction can't touch it, quota exhaustion doesn't erase it, and any
model — including one with zero prior context — can `cat` it and resume.

## Core rule

Maintain `SESSION_LOG.md` continuously as a silent, low-ceremony habit — not
a deliverable to announce. Update it in place; don't regenerate it from
scratch unless its structure is missing entirely. Treat routine updates as
internal bookkeeping: don't narrate "updating the log now" in user-facing
responses unless the user asks about it, the content explains a decision or
blocker, or an update attempt fails.

## When to update

Not just at the end of a session — update it the moment any of these happen:

- starting a meaningful new task
- finishing a task
- discovering a blocker, bug, or uncertainty
- making an important technical decision
- identifying follow-up work
- changing direction
- stopping because of quota, interruption, or context switching
- writing or executing on a spec/plan (this is what
  `session-log-spec-reminder.sh` catches)
- landing a git commit or merge (this is what
  `session-log-commit-reminder.sh` catches)

Before sending a final response after substantial work, confirm the log is
current. If a stop is about to happen unexpectedly, update the log *first*.

## Required structure

```markdown
# Session Log

## Current Work
- What is actively being worked on right now
- Relevant files, functions, or systems
- Current status

## Next Steps
- Ordered checklist of the most important remaining tasks
- Specific and actionable, not vague

## Known Issues
- Bugs, blockers, uncertainties, failing tests, missing information
- Reproduction details, commands, error messages where useful

## Recent Decisions
- Important choices made, and why

## Changed Files
- Files touched this session, one-line reason each

## Resume Notes
- Short handoff note for the next model
- State the exact best next action to take
```

## Quality bar

`Current Work`, `Next Steps`, and `Resume Notes` matter most — keep them
accurate above everything else. Write every entry so a *different* model,
with zero conversation history, could continue immediately: exact file
paths, function names, commands, failing checks. Don't pad it with obvious
or repetitive notes; remove stale/resolved noise as you go rather than
letting it accumulate. The measure of a good entry is "does this let someone
with no memory of this conversation pick up cleanly right now."
