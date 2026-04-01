#!/bin/bash
# Post-commit squash hint — scores the last commit for squashability
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only fire on git commit commands
echo "$CMD" | grep -qE '^\s*git\s+commit\b' || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

MSG=$(git log -1 --format=%s 2>/dev/null)
LINES=$(git show --stat --format="" HEAD 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | grep -oE '[0-9]+' | paste -sd+ - | bc 2>/dev/null || echo "999")
FILES=$(git show --name-only --format="" HEAD 2>/dev/null | wc -l | tr -d ' ')

SCORE=0; REASONS=""

# Message signals
if echo "$MSG" | grep -qiE '^(fixup|squash|amend)!\s'; then SCORE=$((SCORE+90)); REASONS="fixup marker"
elif echo "$MSG" | grep -qiE '^wip\b'; then SCORE=$((SCORE+80)); REASONS="WIP"
elif echo "$MSG" | grep -qiE '^(oops|whoops|forgot|missed)\b'; then SCORE=$((SCORE+80)); REASONS="oops/forgot"
elif echo "$MSG" | grep -qiE '^(fix\s+)?(typo|spelling|whitespace|indent|formatting|lint)\b'; then SCORE=$((SCORE+60)); REASONS="trivial fix"
elif echo "$MSG" | grep -qiE '^(minor|small|tiny|trivial|nit|cleanup|polish)\b'; then SCORE=$((SCORE+50)); REASONS="minor/cleanup"
fi

# Diff signals
[ "$LINES" -le 3 ] 2>/dev/null && SCORE=$((SCORE+40)) && REASONS="${REASONS:+$REASONS, }tiny diff"
[ "$LINES" -le 10 ] 2>/dev/null && [ "$LINES" -gt 3 ] 2>/dev/null && SCORE=$((SCORE+20)) && REASONS="${REASONS:+$REASONS, }small diff"
[ "$FILES" -le 1 ] 2>/dev/null && SCORE=$((SCORE+15)) && REASONS="${REASONS:+$REASONS, }1 file"

[ "$SCORE" -gt 100 ] && SCORE=100

if [ "$SCORE" -ge 60 ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"Squash hint: commit '${MSG}' scores ${SCORE}/100 (${REASONS}). Consider /squash to fold it into the previous commit.\"}}"
fi
