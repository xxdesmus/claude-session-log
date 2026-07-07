#!/bin/bash
# PostToolUse(Bash) hook: after a git commit or merge lands, nudge if
# SESSION_LOG.md wasn't part of it. Requires a per-project CLAUDE.md
# instruction to keep SESSION_LOG.md current; this catches the case where a
# multi-step build (or a subagent working in a worktree) lands commits
# without ever carrying that update forward.
input=$(cat)
[[ $input == *'git commit'* || $input == *'git merge'* ]] || exit 0
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
echo "$cmd" | grep -qE 'git (commit|merge)\b' || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
git show -1 --name-only HEAD 2>/dev/null | grep -qxF 'SESSION_LOG.md' && exit 0
echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Reminder: the last git commit/merge did not touch SESSION_LOG.md. Update it now per CLAUDE.md instructions (a one-line directional note is fine for smaller changes)."}}'
