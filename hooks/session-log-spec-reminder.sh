#!/bin/bash
# PostToolUse(Write|Edit) hook: nudge to update SESSION_LOG.md whenever a
# spec or implementation plan gets written (docs/superpowers/specs|plans).
# These mark the start of a body of work worth a durable handoff note, and
# are an easy, unambiguous trigger point distinct from the general
# per-commit reminder (session-log-commit-reminder.sh).
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')
case "$path" in
  *docs/superpowers/specs/*|*docs/superpowers/plans/*) ;;
  *) exit 0 ;;
esac
jq -n --arg p "$path" '{hookSpecificOutput:{hookEventName:"PostToolUse", additionalContext:("A spec/plan file was just written (" + $p + "). Note this in SESSION_LOG.md now (even a one-line directional note) so the next session can pick up context.")}}'
